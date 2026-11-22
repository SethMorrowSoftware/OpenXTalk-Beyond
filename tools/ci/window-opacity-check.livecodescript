script "oxt_window_opacity_check"
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

-- A stack's window at the opacity its blendLevel gives it, as the screen
-- shows it, for tools/ci/window_opacity_check.py (see there). The forum's
-- report on 2026-11-21 (bwmilby, p=26650): on a Mac the IDE's Message
-- Box never appeared. As the IDE starts it opens the Message Box
-- invisible at a blendLevel of 99, closes it and sets the blendLevel to
-- 0 twice; the second set lost the first, and the window the stack kept
-- stayed at the opacity it was made with (engine/src/exec-interface-
-- stack.cpp, MCStack::SetBlendLevel).
--
-- It runs as the development engine's home stack on a Mac (copied to
-- <folder>/Startup.rev with REV_TOOLS_PATH set to <folder>) and as the
-- standalone engine's stack on Linux ("<engine> <this file>").
--
-- Environment variable OXT_WO_DIR: a folder. The script appends its lines
-- to log.txt there, fields separated by tabs, and after each SHOT line
-- goes on once the file go-<name> is there:
--    INFO    name  value
--    SHOT    name  expected  left,top,right,bottom  windowId
--            expected is "shown" (the stack's colour on the screen) or
--            "clear" (the window all but see-through, at blendLevel 99)
--    ERROR   where  text
--    DONE
-- Exit code 0 when it ran to its end, 2 when OXT_WO_DIR is not set, 3 on
-- a script error.

constant kStack = "oxt_window_opacity"
constant kPalette = "oxt_window_opacity_palette"
-- a colour no desktop is: the window is that colour when it shows
constant kColour = "0,255,0"
constant kRect = "200,200,600,500"

local sDir

on startup
   put $OXT_WO_DIR into sDir
   replace "\" with "/" in sDir
   if the last char of sDir is "/" then delete the last char of sDir
   if sDir is empty then
      write "OXT_WO_DIR is not set" & return to stdout
      quit 2
   end if
   try
      runOpacityCheck
      logLine "DONE"
   catch tError
      logLine "ERROR" & tab & "script" & tab & oneLine(tError)
      quit 3
   end try
   quit 0
end startup

command runOpacityCheck
   logLine "INFO" & tab & "version" & tab & the version && "build" && the buildNumber
   logLine "INFO" & tab & "platform" & tab & the platform && the systemVersion && the processor
   -- palettes stay on the screen while another program is in front
   set the hidePalettes to false

   -- 1. A window at blendLevel 0: the stack's colour on the screen (else
   -- the check cannot see the window)
   makeStack kStack
   show stack kStack
   wait 1 second with messages
   shot "seen", "shown", kStack

   -- 2. At blendLevel 99: all but see-through (else the screen does not
   -- show a window's opacity, and the check cannot judge one)
   set the blendLevel of stack kStack to 99
   wait 1 second with messages
   shot "see-through", "clear", kStack

   -- 3. Set to 0 twice with the screen locked, so that the window is not
   -- updated between the two: it shows again. The second set made the
   -- window miss the first
   lock screen
   set the blendLevel of stack kStack to 0
   set the blendLevel of stack kStack to 0
   unlock screen
   wait 1 second with messages
   shot "set-twice", "shown", kStack
   close stack kStack

   -- 4. As the IDE starts the Message Box (ensureMBcorrect in its stack
   -- script, revInternal__InitialiseMessageBox and tCloseSplashFully in
   -- home.livecodescript), then opens it from the menu: made invisible as
   -- a palette at blendLevel 99, closed, set to 0 twice while closed, and
   -- opened as a palette again in the window it kept. It never appeared
   -- on a Mac (p=26650)
   makeStack kPalette
   close stack kPalette
   set the blendLevel of stack kPalette to 99
   go invisible stack kPalette as palette
   close stack kPalette
   set the visible of stack kPalette to true
   set the blendLevel of stack kPalette to 0
   set the blendLevel of stack kPalette to 0
   palette stack kPalette
   wait 1 second with messages
   shot "reopened", "shown", kPalette
   close stack kPalette
end runOpacityCheck

-- A stack whose window is all kColour (its card is filled by its
-- backgroundColor alone), invisible
private command makeStack pName
   create invisible stack pName
   set the rect of stack pName to kRect
   set the resizable of stack pName to false
   set the backgroundColor of stack pName to kColour
   set the title of stack pName to pName
end makeStack

-- Says where the stack is on the screen and waits until the driver has
-- looked at it (go-<name>), at most two minutes
private command shot pName, pExpected, pStack
   local tGo
   logLine "SHOT" & tab & pName & tab & pExpected & tab & the rect of stack pStack & tab & the windowId of stack pStack
   put sDir & "/go-" & pName into tGo
   repeat 1200 times
      if there is a file tGo then exit shot
      wait 100 milliseconds with messages
   end repeat
   logLine "ERROR" & tab & pName & tab & "no go-" & pName & " within two minutes"
end shot

private command logLine pText
   put pText & return after url ("binfile:" & sDir & "/log.txt")
end logLine

private function oneLine pText
   replace return with " / " in pText
   return pText
end oneLine
