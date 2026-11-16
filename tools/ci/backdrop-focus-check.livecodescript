script "OXTBackdropFocusCheck"
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

-- The stacks for tools/ci/backdrop_focus_check.py (see there), which runs
--
--    <standalone engine> tools/ci/backdrop-focus-check.livecodescript
--
-- on Linux under Xvfb and a window manager, and types and clicks from
-- outside. Environment:
--    OXT_BF_DIR       a folder: the script appends its lines (READY n,
--                     FIELD n ..., EVENT ..., ERROR ..., DONE) to log.txt
--                     and goes on from step n once go-n exists there
--    OXT_BF_BACKDROP  the backdrop to show, or empty for none

command logLine pText
   put pText & return after URL ("binfile:" & $OXT_BF_DIR & "/log.txt")
end logLine

-- Called by the main stack's card script
command bfEvent pEvent
   logLine "EVENT " & pEvent
end bfEvent

command waitGo pStep
   repeat 1200 times
      if there is a file ($OXT_BF_DIR & "/go-" & pStep) then exit waitGo
      wait 100 milliseconds with messages
   end repeat
   logLine "ERROR no go-" & pStep
end waitGo

on startup
   try
      runCheck
   catch tError
      logLine "ERROR " & line 1 of tError
   end try
   logLine "DONE"
   quit
end startup

command runCheck
   local tScript
   logLine "INFO platform=" & the platform & " version=" & the version & " backdrop=" & $OXT_BF_BACKDROP
   if $OXT_BF_BACKDROP is not empty then
      set the backdrop to $OXT_BF_BACKDROP
   end if

   -- The main stack, with a field that has the keyboard. Its card hears
   -- the clicks into the backdrop (sent to the defaultStack's card)
   create stack "BFMain"
   set the rect of stack "BFMain" to 100,100,500,400
   put "on mouseDownInBackdrop pButton" & return & \
         "   send (" & quote & "bfEvent" && "mouseDownInBackdrop" & quote & " && pButton) to stack " & quote & "OXTBackdropFocusCheck" & quote & return & \
         "end mouseDownInBackdrop" into tScript
   set the script of card 1 of stack "BFMain" to tScript
   set the defaultStack to "BFMain"
   create field "Typing"
   set the rect of field "Typing" of stack "BFMain" to 20,20,380,60
   go stack "BFMain"
   set the defaultStack to "BFMain"
   focus on field "Typing" of stack "BFMain"

   -- 1: a palette over it, which the check clicks into to give it the
   -- keyboard, as a user does with the IDE's Message Box
   create stack "BFPalette"
   set the rect of stack "BFPalette" to 600,100,800,300
   set the defaultStack to "BFPalette"
   create field "Other"
   set the rect of field "Other" of stack "BFPalette" to 10,10,190,50
   palette stack "BFPalette"
   set the defaultStack to "BFMain"
   logLine "READY 1"
   waitGo 1

   -- 2: the palette closed, as Ctrl+M closes the Message Box: the check
   -- types, and the keys must reach the main stack's field
   close stack "BFPalette"
   logLine "READY 2"
   waitGo 2
   logLine "FIELD 2 " & field "Typing" of stack "BFMain"

   -- 3: a click into the backdrop (where there is one), and keys typed
   -- after it: they reach the field too
   put empty into field "Typing" of stack "BFMain"
   focus on field "Typing" of stack "BFMain"
   logLine "READY 3"
   waitGo 3
   logLine "FIELD 3 " & field "Typing" of stack "BFMain"
end runCheck
