script "WobbleFortsCheck"
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

-- The stack that tools/ci/wobble_forts_check.py puts beside Wobble Forts
-- (tools/web-player/stacks/Wobble Forts.oxtstack) in its web standalone:
-- the page calls these handlers (the stack's cJavascriptHandlers, set
-- as it is deployed) to see what the game shows. The touches themselves
-- are the page's, as a phone sends them.

constant kGame = "Wobble Forts"

local sErrors

-- Called once the page has opened: this stack goes into the message
-- path, behind everything, to hear of a script error anywhere in the
-- game (errorDialog), which a standalone would otherwise only show
function wcBegin
   if the long id of me is not among the lines of the backScripts then
      insert the script of me into back
   end if
   put empty into sErrors
   return "done"
end wcBegin

on errorDialog pError
   put pError & return & "--" & return after sErrors
end errorDialog

-- The script errors since wcBegin, empty if there were none
function wcErrors
   return sErrors
end wcErrors

-- How the game is: its wfState, a line each, name:value
function wcState
   local tState
   if there is not a stack kGame then
      return empty
   end if
   dispatch function "wfState" to stack kGame
   put the result into tState
   return tState
end wcState

-- Where a control of the game is, on its card (left,top,right,bottom):
-- "hidden" if it is not shown, empty if there is none
function wcRect pName
   local tRect
   if there is not a control pName of card "Fort" of stack kGame then
      return empty
   end if
   put the rect of control pName of card "Fort" of stack kGame into tRect
   if not the visible of control pName of card "Fort" of stack kGame then
      return "hidden"
   end if
   return tRect
end wcRect

-- Every Grump popped (wfTestPopGrumps), to see the fort cleared without
-- a finger's aim
function wcPopGrumps
   dispatch "wfTestPopGrumps" to stack kGame
   return "done"
end wcPopGrumps
