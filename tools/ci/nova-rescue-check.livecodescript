script "NovaRescueCheck"
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

-- The stack that tools/ci/nova_rescue_check.py puts beside Nova Rescue
-- (tools/web-player/stacks/Nova Rescue.oxtstack) in its web standalone:
-- the page calls these handlers (the stack's cJavascriptHandlers, set
-- as it is deployed) to see what the game shows. The touches themselves
-- are the page's, as a phone sends them.

constant kGame = "Nova Rescue"

local sErrors

-- Called once the page has opened: this stack goes into the message
-- path, behind everything, to hear of a script error anywhere in the
-- game (errorDialog), which a standalone would otherwise only show
function ncBegin
   if the long id of me is not among the lines of the backScripts then
      insert the script of me into back
   end if
   put empty into sErrors
   return "done"
end ncBegin

on errorDialog pError
   put pError & return & "--" & return after sErrors
end errorDialog

-- The script errors since ncBegin, empty if there were none
function ncErrors
   return sErrors
end ncErrors

-- How the game is: its nrState, a line each, name:value
function ncState
   local tState
   if there is not a stack kGame then
      return empty
   end if
   dispatch function "nrState" to stack kGame
   put the result into tState
   return tState
end ncState

-- Where a control of the game is, on its card (left,top,right,bottom),
-- and whether it is shown: empty if there is none
function ncRect pName
   local tRect
   if there is not a control pName of card "Space" of stack kGame then
      return empty
   end if
   put the rect of control pName of card "Space" of stack kGame into tRect
   if not the visible of control pName of card "Space" of stack kGame then
      return "hidden"
   end if
   return tRect
end ncRect

-- A thing put where the check wants it (nrTestPut): an astronaut on
-- the ship, to be rescued
function ncPut pKind, pX, pY, pSpeed
   dispatch "nrTestPut" to stack kGame with pKind, pX, pY, pSpeed
   return "done"
end ncPut

-- Whether new things come by themselves (nrTestSpawning)
function ncSpawning pOn
   dispatch "nrTestSpawning" to stack kGame with pOn
   return "done"
end ncSpawning
