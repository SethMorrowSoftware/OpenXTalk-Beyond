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
   TestAssert "T31: a string closed at the end of the line", line 8 of tScript is "  domenu " & quote & "Quit HyperCard" & quote
   TestAssert "T22: delete menuItem from menu", line 9 of tScript is "  hcDeleteMenuItem " & quote & "Edit" & quote & ", " & quote & "New Card" & quote
   TestAssert "T5: notes after a tempo in a variable", line 10 of tScript is "  play harpsichord tempo t " & quote & "c5e d e" & quote
   TestAssert "T3: a field named cards", line 11 of tScript is "  put card field " & quote & "cards" & quote & " into x"

   put _Rewrite("on mouseUp", "  set the visible of tool window to not the visible of tool window", "  if the visible of the message watcher then beep", "end mouseUp") into tScript
   TestAssert "T28: HyperCard's own windows: set", line 2 of tScript is "  hcSetWindow " & quote & "visible" & quote & ", " & quote & "tool" & quote & ", not hcWindowProperty(" & quote & "visible" & quote & ", " & quote & "tool" & quote & ")"
   TestAssert "T28: the message watcher is not the message box", line 3 of tScript is "  if hcWindowProperty(" & quote & "visible" & quote & ", " & quote & "message watcher" & quote & ") then beep"
end TestHyperCardScriptsRules

on TestHyperCardScriptsRulesForAll
   -- the rules that apply to every script, compiling or not: each takes
   -- a statement that stops with an error here where HyperCard went on
   local tScript, q
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
   TestAssert "T26: the loc of a window: unchanged", line 6 of tScript is "  set the loc of window " & q & "Map" & q & " to 10,10"

   put _Rewrite("on mouseUp", "  doMenu new card", "  if x then doMenu Compact Stack", "  doMenu tItem", "  doMenu the short name of me", "end mouseUp") into tScript
   TestAssert "T27: doMenu with the item not in quotes", line 2 of tScript is "  doMenu " & q & "new card" & q
   TestAssert "T27: after then, its spelling kept", line 3 of tScript is "  if x then doMenu " & q & "Compact Stack" & q
   TestAssert "T27: a variable: unchanged", line 4 of tScript is "  doMenu tItem"
   TestAssert "T27: an expression: unchanged", line 5 of tScript is "  doMenu the short name of me"

   put _Rewrite("on mouseUp", "  put the visible of msg into v", "  if the visible of window " & q & "Message" & q & " then hide msg", "  set the loc of the message box to 18,30", "  set loc of msg to x", "  put the length of msg into n", "  put the rect of window " & q & "Map" & q & " into r", "end mouseUp") into tScript
   TestAssert "T28: the visible of msg", line 2 of tScript is "  put hcMessageBox(" & q & "visible" & q & ") into v"
   TestAssert "T28: the visible of window " & q & "Message" & q, line 3 of tScript is "  if hcMessageBox(" & q & "visible" & q & ") then hide msg"
   TestAssert "T28: set the loc of the message box", line 4 of tScript is "  hcSetMessageBox " & q & "loc" & q & ", 18,30"
   TestAssert "T28: set loc of msg", line 5 of tScript is "  hcSetMessageBox " & q & "loc" & q & ", x"
   TestAssert "T28: the length of msg: unchanged", line 6 of tScript is "  put the length of msg into n"
   TestAssert "T28: another window: unchanged", line 7 of tScript is "  put the rect of window " & q & "Map" & q & " into r"

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
   TestAssert "T33: doMenu with dots in the item's name", line 11 of tScript is "  doMenu " & q & "New Stack..." & q

   -- the corpus sweep: a modifier key after "with" stays bare, and the
   -- long version of HyperCard is still T10's
   put _Rewrite("on mouseUp", "  type " & q & "C" & q & " with commandKey", "  drag from 1,1 to 9,9 with optionKey, shiftKey", "  get the long version of HyperCard", "end mouseUp") into tScript
   TestAssert "T33: a modifier key after with: unchanged", line 2 of tScript is "  type " & q & "C" & q & " with commandKey"
   TestAssert "T33: modifier keys after with: unchanged", line 3 of tScript is "  drag from 1,1 to 9,9 with optionKey, shiftKey"
   TestAssert "T33: the long version of HyperCard: still T10's", line 4 of tScript is "  get hcLongVersion()"
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
   TestAssert "T35: doMenu one word", line 5 of tScript is "  doMenu " & q & "Next" & q
   TestAssert "T35: play's notes not in quotes", line 6 of tScript is "  play harpsichord " & q & "c d e f fast" & q
   TestAssert "T35: play's notes after tempo", line 7 of tScript is "  play flute tempo 200 " & q & "c4 d" & q
   TestAssert "T35: send to card after then", line 8 of tScript is "  if x then send " & q & "go" & q & " to this card"
   TestAssert "T35: is not off", line 9 of tScript is "  if y is not " & q & "off" & q & " then beep"
   TestAssert "T35: the script compiles", _Compiles(tScript)

   -- unchanged: a count put into the message box, a variable after
   -- play's voice, a variable named on, doMenu with a variable, quoted
   -- notes
   put _Rewrite("on mouseUp", "  put the number of words in fld 1", "  play flute tNotes", \
         "  put 1 into tItem; put 2 into tNotes", "  doMenu tItem", "  play " & q & "boing" & q & " " & q & "c d" & q, \
         "  put x in y into z", "end mouseUp") into tScript
   TestAssert "T35: a count into the message box: unchanged", line 2 of tScript is "  put the number of words in fld 1"
   TestAssert "T35: play with a variable: unchanged", line 3 of tScript is "  play flute tNotes"
   TestAssert "T35: doMenu with a variable: unchanged", line 5 of tScript is "  doMenu tItem"
   TestAssert "T35: quoted notes: unchanged", line 6 of tScript is "  play " & q & "boing" & q & " " & q & "c d" & q
   TestAssert "T35: in before into: unchanged", line 7 of tScript is "  put x in y into z"
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
   unlock messages
   get revHyperCardFixScripts(tStack)
   put empty into gHCScriptsTest
   try
      send "mouseUp" to button "B" of stack tStack
   catch tError
   end try
   TestAssert "messages sent to no handler end in the library", tError is empty
   TestAssert "MultiFinder, FileExists and CapsLock answer", gHCScriptsTest is "true,false,true"
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
   set the script of button "Mixed" to _Lines("on mouseUp", "  put 2 into y", "end mouseUp", "on mouseDown", "  put 1 +* into", "end mouseDown")
   unlock messages
   get revHyperCardFixScripts(tStack)
   put revHyperCardLeftOutHandlers() into tLeft
   TestAssert "the handler left out is listed", tLeft[1]["name"] is "mouseDown" and tLeft[1]["error"] is not empty
   put revHyperCardImportSummary(tStack, "Not converting snd  id  9 " & quote & "Boo" & quote & ": MACE 3:1 compression" & return & "Not converting XCMD id 3 " & quote & "Ink" & quote) into tSummary
   TestAssert "the summary names the stack", line 1 of tSummary begins with tStack & ":"
   TestAssert "the summary names the handler left out", "mouseDown in button" is in tSummary
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
   -- (4 scripts that did not compile; 33 that did, for "go home",
   -- "arrowKey", the cursor and "go" to another stack, by "stack" or by
   -- its name alone)
   TestAssert "TestV1: scripts rewritten", "HyperCard scripts: 37 rewritten" is in tReport
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
