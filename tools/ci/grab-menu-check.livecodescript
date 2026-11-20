script "oxt_grab_menu_check"
-- Copyright (C) 2026 OXT-Beyond contributors.
--
-- This file is part of OXT-Beyond.
--
-- OXT-Beyond is free software; you can redistribute it and/or modify it under
-- the terms of the GNU General Public License v3 as published by the Free
-- Software Foundation.
--
-- OXT-Beyond is distributed in the hope that it will be useful, but WITHOUT ANY
-- WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
-- FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
-- details.
--
-- You should have received a copy of the GNU General Public License
-- along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.

-- The stack of tools/ci/grab_menu_check.py: a group whose script grabs it
-- on mouseDown ("grab me", the usual way to drag a thing), with a menu
-- button in it. A press on the menu button reaches the group's mouseDown,
-- the group is grabbed and the button's menu opens; when the mouse button
-- came up the engine crashed, in LiveCode Community 9.6.3 too (openxtalk.org
-- p=9443, p=9448). A plain button beside it, grabbed by its own script,
-- shows that a grab still drags.
--
-- A second thing is checked from the same stack, with OXT_GRAB_MENU_MODE
-- "nomouse": "popup button" from a timer while the mouse is over none of
-- the program's stacks. Up to 0.2.8-dp.2, and in LiveCode Community, that
-- ended in error 583 (no such stack) and no menu; the menu now opens at
-- the mouse and its pick arrives.
--
-- Environment: OXT_GRAB_MENU_LOG (the file the lines go to) and
-- OXT_GRAB_MENU_MODE (the menuMode of the button: popup, option or
-- pulldown). The window is at 100,100 on the screen, the menu button's
-- middle at 225,165 and the plain button's at 225,265.

on startup
   insert the script of me into back
   create stack "GrabMenu"
   set the rect of stack "GrabMenu" to 100,100,500,400
   set the defaultStack to "GrabMenu"
   create button "Menu"
   set the style of button "Menu" to "menu"
   if $OXT_GRAB_MENU_MODE is "nomouse" then
      set the menuMode of button "Menu" to "popup"
   else
      set the menuMode of button "Menu" to $OXT_GRAB_MENU_MODE
   end if
   set the text of button "Menu" to "One" & return & "Two" & return & "Three"
   set the rect of button "Menu" to 50,50,200,80
   create group "Dragged"
   relayer button "Menu" to front of group "Dragged"
   set the script of group "Dragged" to "on mouseDown" & return & "logLine " & quote & "GROUP mouseDown" & quote & return & "grab me" & return & "end mouseDown"
   create button "Plain"
   set the rect of button "Plain" to 50,150,200,180
   set the script of button "Plain" to "on mouseDown" & return & "logLine " & quote & "PLAIN mouseDown" & quote & return & "grab me" & return & "end mouseDown"
   if $OXT_GRAB_MENU_MODE is "nomouse" then
      set the script of button "Menu" to "on menuPick pItem" & return & "logLine " & quote & "PICK " & quote & " & pItem" & return & "end menuPick"
      send "grabMenuPopup" to me in 3 seconds
   end if
   go stack "GrabMenu"
   logLine "READY"
   send "grabMenuAlive" to me in 500 milliseconds
end startup

-- A line every half second while the engine runs, with where the plain
-- button is, so that the Python side sees it go on after the release and
-- sees the drag
on grabMenuAlive
   if $OXT_GRAB_MENU_MODE is "nomouse" then
      -- (and where the engine has the mouse, for a run that failed)
      logLine "ALIVE" && the loc of button "Plain" of stack "GrabMenu" && "mouseStack [" & the mouseStack & "] mouseLoc" && the mouseLoc && "screenMouseLoc" && the screenMouseLoc
   else
      logLine "ALIVE" && the loc of button "Plain" of stack "GrabMenu"
   end if
   send "grabMenuAlive" to me in 500 milliseconds
end grabMenuAlive

on grabMenuPopup
   logLine "MOUSESTACK [" & the mouseStack & "]"
   try
      logLine "POPUP opening"
      popup button "Menu" of stack "GrabMenu"
      logLine "POPUP returned"
   catch tError
      logLine "POPUP ERROR" && item 1 of line 1 of tError
   end try
end grabMenuPopup

on logLine pLine
   open file $OXT_GRAB_MENU_LOG for append
   write pLine & linefeed to file $OXT_GRAB_MENU_LOG
   close file $OXT_GRAB_MENU_LOG
end logLine
