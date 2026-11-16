script "EmberBricksCheck"
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

-- The stack that tools/ci/ember_bricks_check.py puts beside Ember Bricks
-- (tools/web-player/stacks/Ember Bricks.oxtstack) in its web standalone:
-- the page calls these handlers (the stack's cJavascriptHandlers, set
-- as it is deployed) to see what the game shows, and to put a duel's
-- clock and score where a check can wait for them. The touches
-- themselves, and everything a duel's two pages say to each other, are
-- the pages' own.

constant kGame = "Ember Bricks"
constant kCard = "Game"

local sErrors

-- Called once the page has opened: this stack goes into the message
-- path, behind everything, to hear of a script error anywhere in the
-- game (errorDialog), which a standalone would otherwise only show
function ecBegin
   if the long id of me is not among the lines of the backScripts then
      insert the script of me into back
   end if
   put empty into sErrors
   return "done"
end ecBegin

on errorDialog pError
   put pError & return & "--" & return after sErrors
end errorDialog

-- The script errors since ecBegin, empty if there were none
function ecErrors
   return sErrors
end ecErrors

-- How the game is: its ebState, a line each, name:value
function ecState
   local tState
   if there is not a stack kGame then
      return empty
   end if
   dispatch function "ebState" to stack kGame
   put the result into tState
   return tState
end ecState

-- Where a control of the game is, on its card (left,top,right,bottom):
-- "hidden" if it, or the screen it is of, is not shown; empty if there
-- is none
function ecRect pName
   local tRect
   if there is not a control pName of card kCard of stack kGame then
      return empty
   end if
   put the rect of control pName of card kCard of stack kGame into tRect
   if not the effective visible of control pName of card kCard of stack kGame then
      return "hidden"
   end if
   return tRect
end ecRect

-- What a field of the game says
function ecText pName
   if there is not a field pName of card kCard of stack kGame then
      return empty
   end if
   return the text of field pName of card kCard of stack kGame
end ecText

-- A thing of the run as the check wants it (the game's ebTestSet): a
-- score for the rival to see, or the seconds a duel has left
function ecSet pName, pValue
   dispatch "ebTestSet" to stack kGame with pName, pValue
   return "done"
end ecSet
