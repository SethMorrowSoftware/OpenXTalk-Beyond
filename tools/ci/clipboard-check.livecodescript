script "OXTClipboardCheck"
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

-- Run by tools/ci/clipboard_check.py: puts $OXT_CLIPBOARD_TEXT on the
-- clipboard, says so in $OXT_CLIPBOARD_LOG and quits. Whether the text
-- outlives the engine is what the Python script checks.

command logLine pText
   put pText & return after URL ("binfile:" & $OXT_CLIPBOARD_LOG)
end logLine

on startup
   logLine "INFO platform=" & the platform & " version=" & the version & " processor=" & the processor
   try
      set the clipboardData["text"] to $OXT_CLIPBOARD_TEXT
      -- Read it back: the engine's own view of the clipboard
      logLine "SET " & (the clipboardData["text"] is $OXT_CLIPBOARD_TEXT)
   catch tError
      logLine "ERROR " & tError
   end try
   logLine "QUIT " & the milliseconds
   quit
end startup
