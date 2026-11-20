script "AndroidStackPlayerBack"
/*
Copyright (C) 2026 OXT-Beyond contributors.

This file is part of OXT-Beyond.

OXT-Beyond is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

OXT-Beyond is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
details.

You should have received a copy of the GNU General Public License
along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.  */

-- The Android Stack Player's back script (tools/android-player): the
-- script of the button "Player Back Script" of the player's stack, which
-- its openStack inserts into the back. It is where the messages end that
-- the stack that plays does not handle, after that stack's own scripts
-- and before the engine: a stack that handles one of them itself, and
-- does not pass it, keeps it.

constant kPlayerName = "OXT Stack Player"

-- Android's Back. Unhandled, the engine quits the app: while a stack
-- plays it comes home to the player instead, and at home it leaves the
-- app as before.
on backKey
   local tCurrent
   dispatch function "playerCurrent" to stack kPlayerName
   put the result into tCurrent
   if tCurrent is empty then
      pass backKey
   end if
   dispatch "playerSay" to stack kPlayerName with "back"
   dispatch "playerHome" to stack kPlayerName
end backKey

-- A file opened with the player from another app while it runs
on urlWakeUp pAddress
   dispatch "playerTakeAddress" to stack kPlayerName with pAddress
end urlWakeUp

on errorDialog pError
   dispatch "playerScriptError" to stack kPlayerName with pError, the long id of the target
end errorDialog
