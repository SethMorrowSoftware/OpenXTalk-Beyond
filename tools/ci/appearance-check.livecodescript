script "OXTAppearanceCheck"
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

-- Run by tools/ci/appearance_check.py, which starts this standalone engine
-- on its own X server with GSettings' keyfile backend in a folder of its
-- own ($OXT_APPEARANCE_KEYFILE), the desktop set to dark there. Each step
-- writes one line to $OXT_APPEARANCE_LOG: the step, the systemAppearance
-- and how many systemAppearanceChanged messages have come so far. The
-- Python script decides what passes.
--
--   DEFAULT   the useDesktopAppearance as the engine starts, and the
--             systemAppearance: false and light
--   OPTIN     after setting it to true, on a dark desktop: dark, 1
--   SWITCH    after the desktop's color-scheme goes to "default": light, 2
--   BACK      and to "prefer-dark" again: dark, 3
--   OPTOUT    after setting it to false: light, 4
--   QUIET     the desktop switched while it is false: light, still 4

local sChanged

command logLine pText
   put pText & return after URL ("binfile:" & $OXT_APPEARANCE_LOG)
end logLine

-- Replaces the keyfile in one step, as a settings tool does, so that
-- GSettings sees one change, not an empty file first
command writeScheme pScheme
   local tFile, tTemp
   put $OXT_APPEARANCE_KEYFILE into tFile
   put tFile & ".new" into tTemp
   put "[org/gnome/desktop/interface]" & return & "color-scheme='" & pScheme & "'" & return into URL ("binfile:" & tTemp)
   rename file tTemp to tFile
   logLine "WROTE" && pScheme && the result
end writeScheme

-- Waits, handling messages, until more than pCount messages have come or
-- pMax milliseconds have passed
command waitForMessage pCount, pMax
   local tEnd
   put the milliseconds + pMax into tEnd
   repeat while sChanged <= pCount and the milliseconds < tEnd
      wait 50 milliseconds with messages
   end repeat
end waitForMessage

command step pName
   logLine pName && the systemAppearance && sChanged
end step

on openStack
   send "runCheck" to me in 200 milliseconds
end openStack

on runCheck
   put 0 into sChanged
   logLine "INFO platform=" & the platform & " version=" & the version & " processor=" & the processor
   try
      logLine "DEFAULT" && the useDesktopAppearance && the systemAppearance && sChanged

      set the useDesktopAppearance to true
      waitForMessage 0, 3000
      step "OPTIN"

      writeScheme "default"
      waitForMessage 1, 8000
      step "SWITCH"

      writeScheme "prefer-dark"
      waitForMessage 2, 8000
      step "BACK"

      set the useDesktopAppearance to false
      waitForMessage 3, 3000
      step "OPTOUT"

      writeScheme "default"
      waitForMessage 4, 4000
      step "QUIET"
   catch tError
      logLine "ERROR" && tError
   end try
   logLine "QUIT" && the milliseconds
   quit
end runCheck

on systemAppearanceChanged
   add 1 to sChanged
   logLine "MESSAGE" && the systemAppearance && sChanged
end systemAppearanceChanged
