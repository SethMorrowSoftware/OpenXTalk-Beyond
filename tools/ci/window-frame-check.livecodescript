script "OXTWindowFrameCheck"
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

-- The stacks tools/ci/window_frame_check.py looks at and clicks from
-- outside (Windows): their windows' frames and minimize buttons. It runs
--
--    <standalone engine> tools/ci/window-frame-check.livecodescript
--
-- Environment:
--    OXT_FRAME_LOG   the file to append lines to: WINDOW <name> <windowID>
--                    for each stack, READY when they are all open, an
--                    ICONIFY <name> for each iconifyStack a stack gets,
--                    then DONE
--    OXT_FRAME_GO    a file window_frame_check.py writes when it is
--                    finished with the windows; the script then quits
--
-- The stacks:
--    FramePlain  a stack with a title bar and minimize box, opened as any
--                stack is: the control
--    FrameFaded  opened the way the IDE opens its menubar
--                (revmenubar.livecodescript): at blendLevel 99 with no
--                decorations, moved and sized while it is translucent,
--                given "title,menu,minimize,close" a moment later under
--                lock screen and lock messages, and then set to
--                blendLevel 0. Up to 0.2.7-rc.6.11 the IDE's menubar,
--                opened like this, ignored a click on its minimize button
--                on Windows 11
--    FrameFadedTitled  at blendLevel 99 with its decorations from the
--                start, moved and sized, then set to blendLevel 0
--
-- Quits when OXT_FRAME_GO appears, or after 180 seconds.

constant kDecorations = "title,menu,minimize,close"

local sStacks

command logLine pText
   put pText & return after URL ("binfile:" & $OXT_FRAME_LOG)
end logLine

-- Called by each stack's iconifyStack handler
command frameCheckIconified pName
   logLine "ICONIFY" && pName
end frameCheckIconified

private function stackScript
   return "on iconifyStack" & return & \
         "   dispatch" && quote & "frameCheckIconified" & quote && "to stack" && quote & "OXTWindowFrameCheck" & quote && "with the short name of me" & return & \
         "   pass iconifyStack" & return & \
         "end iconifyStack"
end stackScript

private command makeStack pName, pRect
   create invisible stack pName
   set the script of stack pName to stackScript()
   set the rect of stack pName to pRect
   set the backgroundColor of stack pName to "#3060A0"
   put pName & return after sStacks
end makeStack

on startup
   logLine "INFO platform=" & the platform & " version=" & the version & " systemVersion=" & the systemVersion
   try
      makeStack "FramePlain", "80,120,580,320"
      set the decorations of stack "FramePlain" to kDecorations
      go stack "FramePlain"

      -- As revmenubar.livecodescript's preOpenStack, then
      -- tMenuBar_AdjustWDSize and tMenuBar_WDdecorations, then
      -- home.livecodescript when the IDE has started
      makeStack "FrameFaded", "640,120,1140,320"
      set the blendLevel of stack "FrameFaded" to 99
      set the decorations of stack "FrameFaded" to empty
      go stack "FrameFaded"
      wait 200 milliseconds with messages
      set the rect of stack "FrameFaded" to 0,0,600,110
      set the topLeft of stack "FrameFaded" to 640,120
      wait 200 milliseconds with messages
      lock screen
      lock messages
      set the decorations of stack "FrameFaded" to kDecorations
      set the top of stack "FrameFaded" to 120
      set the left of stack "FrameFaded" to 640
      unlock messages
      unlock screen
      wait 300 milliseconds with messages
      set the blendLevel of stack "FrameFaded" to 0

      makeStack "FrameFadedTitled", "80,420,580,620"
      set the decorations of stack "FrameFadedTitled" to kDecorations
      set the blendLevel of stack "FrameFadedTitled" to 99
      go stack "FrameFadedTitled"
      wait 200 milliseconds with messages
      set the rect of stack "FrameFadedTitled" to 80,420,640,560
      wait 200 milliseconds with messages
      set the blendLevel of stack "FrameFadedTitled" to 0

      wait 500 milliseconds with messages
      repeat for each line tName in sStacks
         logLine "WINDOW" && tName && the windowID of stack tName
      end repeat
      logLine "READY"
   catch tError
      replace return with " | " in tError
      logLine "ERROR " & tError
   end try

   local tEnd
   put the milliseconds + 180000 into tEnd
   repeat while the milliseconds < tEnd and there is not a file $OXT_FRAME_GO
      wait 100 milliseconds with messages
   end repeat
   logLine "DONE"
   quit 0
end startup
