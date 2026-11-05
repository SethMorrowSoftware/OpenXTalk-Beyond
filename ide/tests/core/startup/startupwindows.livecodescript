script "IDEStartupWindows"
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

-- OXT-Beyond: while the IDE starts, it opens the Tools palette and the
-- Message Box invisible and shows them once the splash has gone. The
-- palette behavior's openStack showed any palette that opened invisible,
-- so both came up for a moment and were hidden again: "ghost windows"
-- before the IDE settled (LittleNemo, openxtalk.org p=25967). A palette
-- opened with cOXTOpenHidden set now stays hidden; every other palette
-- that opens invisible is shown, as before. tools/ci/linux_ide_start.sh
-- watches a real start for windows that come and go
-- (tools/ci/startup_windows.py).

on TestTeardown
   if there is a stack "Message Box" then
      set the cOXTOpenHidden of stack "Message Box" to empty
      close stack "Message Box"
      set the visible of stack "Message Box" to true
   end if
end TestTeardown

-- After the start, no palette is left marked to stay hidden, and the
-- Tools palette is open and shown
on TestStartLeavesNothingHidden
   local tTools
   put revIDEPaletteToStackName("tools") into tTools
   TestAssert "the Tools palette is not left marked to stay hidden", \
         the cOXTOpenHidden of stack tTools is empty
   TestAssert "the Message Box is not left marked to stay hidden", \
         the cOXTOpenHidden of stack "Message Box" is empty
   TestAssert "the Message Box is left to show when it is next opened", \
         the visible of stack "Message Box"
end TestStartLeavesNothingHidden

-- The Message Box opens and shows from the IDE as before
on TestMessageBoxOpensShown
   if there is a stack "Message Box" then close stack "Message Box"
   revIDEOpenPalette "message box"
   wait 100 milliseconds with messages
   TestAssert "the Message Box is open", the mode of stack "Message Box" > 0
   TestAssert "the Message Box is shown", the visible of stack "Message Box"
end TestMessageBoxOpensShown

-- A palette opened invisible is shown by the palette behavior, as before,
-- unless it is marked to stay hidden
on TestPaletteOpenedInvisible
   if there is a stack "Message Box" then close stack "Message Box"
   go invisible stack "Message Box" as palette
   wait 100 milliseconds with messages
   TestAssert "a palette opened invisible is shown, as before", \
         the visible of stack "Message Box"
   close stack "Message Box"

   set the cOXTOpenHidden of stack "Message Box" to true
   go invisible stack "Message Box" as palette
   wait 100 milliseconds with messages
   TestAssert "a palette opened to stay hidden stays hidden", \
         the mode of stack "Message Box" > 0 and not the visible of stack "Message Box"
   close stack "Message Box"
   set the cOXTOpenHidden of stack "Message Box" to empty
   set the visible of stack "Message Box" to true
end TestPaletteOpenedInvisible
