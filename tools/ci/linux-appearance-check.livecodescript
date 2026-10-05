script "OXTLinuxAppearanceCheck"
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

-- Reports what a Linux standalone engine with a user interface makes of
-- the GTK theme it runs in (tools/ci/linux_appearance_check.py gives it a
-- light or a dark one): the systemAppearance, the effective appAppearance
-- with the appAppearance "light" and "system", the effective
-- stackAppearance and the effective backgroundColor of a stack that sets
-- no colour, and the lookAndFeel.
--
-- Environment:
--    OXT_APPEARANCE_LOG   the file to append the result lines to
--                         ("VALUE <name>=<value>", then "DONE")

command logLine pText
   put pText & return after URL ("binfile:" & $OXT_APPEARANCE_LOG)
end logLine

command logValue pName, pValue
   replace return with " | " in pValue
   logLine "VALUE " & pName & "=" & pValue
end logValue

on startup
   local tValue
   try
      logValue "platform", the platform
      logValue "lookAndFeel", the lookAndFeel
      create stack "AppearanceCheck"
      set the rect of stack "AppearanceCheck" to 100,100,500,400
      go stack "AppearanceCheck"
      wait 300 milliseconds with messages
      logValue "systemAppearance", the systemAppearance
      do "put the effective appAppearance into tValue"
      logValue "effective appAppearance light", tValue
      do "set the appAppearance to" && quote & "system" & quote
      do "put the effective appAppearance into tValue"
      logValue "effective appAppearance system", tValue
      do "put the effective stackAppearance of stack" && quote & "AppearanceCheck" & quote && "into tValue"
      logValue "effective stackAppearance", tValue
      logValue "effective backgroundColor", the effective backgroundColor of stack "AppearanceCheck"
   catch tError
      logValue "error", tError
   end try
   logLine "DONE"
   quit 0
end startup
