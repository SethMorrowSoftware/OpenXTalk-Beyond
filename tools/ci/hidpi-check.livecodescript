script "OXTHiDPICheck"
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

-- Run by tools/ci/hidpi_check.py on an X server at 1x or at a desktop
-- scale of 2: logs to $OXT_HIDPI_LOG what the engine says about the
-- screen and its scale, then opens a stack whose fields each hold one
-- line of text, logs where the engine measures each line to end (in
-- screen points), and waits for $OXT_HIDPI_SHOT to exist, while the
-- Python script takes a picture of the screen and compares the glyphs
-- with those places. Then it turns usePixelScaling off, logs the screen
-- again and quits.

constant kText = "The quick brown fox jumps over the lazy dog WM"

command logLine pText
   put pText & return after URL ("binfile:" & $OXT_HIDPI_LOG)
end logLine

command logScreen pWhen
   logLine "SCREEN" && pWhen && the screenRect
   logLine "WORKING" && pWhen && the working screenRect
   logLine "SCALE" && pWhen && the screenPixelScale && the systemPixelScale && the pixelScale && the usePixelScaling
end logScreen

on startup
   logLine "INFO platform=" & the platform & " version=" & the version & " processor=" & the processor
   try
      runCheck
   catch tError
      logLine "ERROR" && tError
   end try
   logLine "QUIT"
   quit
end startup

command runCheck
   local tFonts, tFont, tSize, tTop, tField, tRect, tLeft, tRight, tCount, tEnd
   logScreen "start"

   -- One field for each font and size: Pango rounds each glyph's advance
   -- to a whole pixel, so these sizes give different widths at 1x and 2x
   put empty into tFonts
   repeat for each item tFont in "DejaVu Sans Mono,DejaVu Sans"
      if tFont is among the lines of the fontNames then
         put tFont & return after tFonts
      else
         logLine "NOFONT" && tFont
      end if
   end repeat

   create stack "HiDPICheck"
   set the defaultStack to "HiDPICheck"
   set the backColor of stack "HiDPICheck" to "white"
   set the rect of stack "HiDPICheck" to 0,0,640,30 * 12 + 8
   put 4 into tTop
   put 0 into tCount
   repeat for each line tFont in tFonts
      repeat for each item tSize in "9,10,11,12,13,14"
         add 1 to tCount
         create field ("F" & tCount)
         put it into tField
         set the showBorder of tField to false
         set the opaque of tField to false
         set the dontWrap of tField to true
         set the lockText of tField to true
         set the textFont of tField to tFont
         set the textSize of tField to tSize
         set the textColor of tField to "black"
         set the rect of tField to 48, tTop, 636, tTop + 26
         put kText into tField
         add 30 to tTop
      end repeat
   end repeat
   go stack "HiDPICheck"
   wait 500 milliseconds with messages

   -- Where the engine measures each line to start and end, in screen points
   repeat with tCount = 1 to the number of fields of stack "HiDPICheck"
      put the formattedRect of line 1 of field tCount of stack "HiDPICheck" into tRect
      put item 1 of tRect + the left of stack "HiDPICheck" into tLeft
      put item 3 of tRect + the left of stack "HiDPICheck" into tRight
      logLine "FIELD" && tCount & "|" & the textFont of field tCount & "|" & the textSize of field tCount & "|" & \
            tLeft && (item 2 of tRect + the top of stack "HiDPICheck") && \
            tRight && (item 4 of tRect + the top of stack "HiDPICheck")
   end repeat
   logLine "STACK" && the rect of stack "HiDPICheck"
   logLine "READY"

   -- The picture is taken now
   put the milliseconds + 20000 into tEnd
   repeat until there is a file $OXT_HIDPI_SHOT or the milliseconds > tEnd
      wait 100 milliseconds with messages
   end repeat

   -- The way back to the screen's pixels, where the desktop scales
   try
      set the usePixelScaling to false
      wait 200 milliseconds with messages
      logScreen "unscaled"
   catch tError
      logLine "NOUNSCALE" && tError
   end try
end runCheck
