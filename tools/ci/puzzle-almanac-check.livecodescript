script "PuzzleAlmanacCheck"
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

-- The stack that tools/ci/puzzle_almanac_check.py puts beside Puzzle
-- Almanac (tools/web-player/stacks/Puzzle Almanac.oxtstack) in its web
-- standalone: the page calls these handlers (the stack's
-- cJavascriptHandlers, set as it is deployed) to see what the game
-- shows. The taps themselves are the page's, as a phone sends them.

constant kGame = "Puzzle Almanac"

local sErrors

-- Called once the page has opened: this stack goes into the message
-- path, behind everything, to hear of a script error anywhere in the
-- game (errorDialog), which a standalone would otherwise only show
function pcBegin
   if the long id of me is not among the lines of the backScripts then
      insert the script of me into back
   end if
   put empty into sErrors
   return "done"
end pcBegin

on errorDialog pError
   put pError & return & "--" & return after sErrors
end errorDialog

-- The script errors since pcBegin, empty if there were none
function pcErrors
   return sErrors
end pcErrors

-- How the game is: its paState, a line each, name:value
function pcState
   local tState
   if there is not a stack kGame then
      return empty
   end if
   dispatch function "paState" to stack kGame
   put the result into tState
   return tState
end pcState

-- Where a control of the game is, on its card (left,top,right,bottom):
-- "hidden" if it or a group it is in is not shown, empty if there is
-- none. (Each screen and panel of the game is a group, shown or hidden
-- whole, so a control's own visible is not enough.)
function pcRect pName
   local tControl, tOwner, tDepth
   if there is not a control pName of card "Almanac" of stack kGame then
      return empty
   end if
   put the long id of control pName of card "Almanac" of stack kGame into tControl
   put tControl into tOwner
   repeat with tDepth = 1 to 10
      if word 1 of tOwner is "card" then
         exit repeat
      end if
      if not the visible of tOwner then
         return "hidden"
      end if
      put the long owner of tOwner into tOwner
   end repeat
   return the rect of tControl
end pcRect

-- Every square of the Number Place shown but one written in with its
-- right number, as taps on the square and the key would (the game's
-- paPress): the check taps the last itself. Returns that square's
-- number on the board, and the number that goes in it, "cell,number"
function pcFillAllButOne
   local tBoard, tAnswer, tLast, i
   put pcValue("board") into tBoard
   put pcValue("answer") into tAnswer
   repeat with i = the number of chars of tBoard down to 1
      if char i of tBoard is not char i of tAnswer then
         put i into tLast
         exit repeat
      end if
   end repeat
   if tLast is empty then
      return empty
   end if
   repeat with i = 1 to the number of chars of tBoard
      if i is not tLast and char i of tBoard is not char i of tAnswer then
         -- (a wrong number there, the right one takes its place)
         dispatch "paPress" to stack kGame with "N Cell" && i
         dispatch "paPress" to stack kGame with "N Key" && char i of tAnswer
      end if
   end repeat
   return tLast & comma & char tLast of tAnswer
end pcFillAllButOne

-- One value of paState
private function pcValue pName
   local tLine
   repeat for each line tLine in pcState()
      if tLine begins with pName & ":" then
         return char (the number of chars of pName + 2) to -1 of tLine
      end if
   end repeat
   return empty
end pcValue
