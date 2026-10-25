script "CoreInterfaceScrollbarScale"
/*
Copyright (C) 2026 OXT-Beyond contributors.

This file is part of OXT-Beyond, a fork of LiveCode Community.

LiveCode is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

LiveCode is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with LiveCode.  If not see <http://www.gnu.org/licenses/>.  */

-- OXT-Beyond: sliders (scrollbars whose style is "scale") in a look that
-- the engine draws itself. The engine draws a horizontal one in the
-- Windows look with a groove and a pointed thumb over tick marks, but it
-- drew a vertical one in its older look, a trough with a block for a
-- thumb, so on the web, where no theme draws sliders and the look is
-- Windows, a vertical slider looked like a scrollbar without arrows
-- (bwmilby, forum p=25316). In the web engine a vertical slider is now
-- drawn as the horizontal one is, on its side
-- (engine/src/scrollbardraw.cpp, DrawWinVerticalScale); on the desktop a
-- look that the engine draws draws it as before.

private command _CreateScale pName, pRect
   create scrollbar pName
   set the style of scrollbar pName to "scale"
   set the showValue of scrollbar pName to false
   set the startValue of scrollbar pName to 0
   set the endValue of scrollbar pName to 100
   set the rect of scrollbar pName to pRect
end _CreateScale

-- The pixels of a snapshot of a scrollbar: its width and height, its
-- imageData (4 bytes a pixel) and its alphaData (a byte a pixel)
private function _Pixels pName
   local tPixels
   import snapshot from scrollbar pName
   put the width of the last image into tPixels["width"]
   put the height of the last image into tPixels["height"]
   put the imageData of the last image into tPixels["image"]
   put the alphaData of the last image into tPixels["alpha"]
   delete the last image
   return tPixels
end _Pixels

-- How many pixels of the snapshot pH differ from those of the snapshot pV
-- turned on its side: the pixel at (x, y) of pH against the one at (y, x)
-- of pV, in colour and in alpha. Each is compared as text that begins
-- with a letter, so that bytes that read as a number are not compared as
-- numbers.
private function _DifferencesOnItsSide pH, pV
   local tCount, tX, tY, tH, tV
   set the caseSensitive to true
   put 0 into tCount
   repeat with tY = 0 to pH["height"] - 1
      repeat with tX = 0 to pH["width"] - 1
         put tY * pH["width"] + tX into tH
         put tX * pV["width"] + tY into tV
         if "x" & byte (4 * tH + 2) to (4 * tH + 4) of pH["image"] is not \
               "x" & byte (4 * tV + 2) to (4 * tV + 4) of pV["image"] or \
               "x" & byte (tH + 1) of pH["alpha"] is not \
               "x" & byte (tV + 1) of pV["alpha"] then
            add 1 to tCount
         end if
      end repeat
   end repeat
   return tCount
end _DifferencesOnItsSide

-- Compares a horizontal slider pAcross pixels high with a vertical one
-- pAcross pixels wide, both 200 pixels long, at each of pPositions and
-- enabled and disabled; returns a line for each:
-- <position>,<enabled>,<pixels>,<pixels that differ>
private function _CompareOnItsSide pAcross, pPositions
   local tResults, tPosition, tEnabled, tH, tV
   _CreateScale "H", "0,0,200," & pAcross
   _CreateScale "V", "0,40," & pAcross & ",240"
   repeat for each item tPosition in pPositions
      repeat for each item tEnabled in "true,false"
         set the thumbPosition of scrollbar "H" to tPosition
         set the thumbPosition of scrollbar "V" to tPosition
         set the enabled of scrollbar "H" to tEnabled
         set the enabled of scrollbar "V" to tEnabled
         put _Pixels("H") into tH
         put _Pixels("V") into tV
         if tH["width"] is not tV["height"] or tH["height"] is not tV["width"] \
               or the number of bytes in tH["alpha"] is not tH["width"] * tH["height"] \
               or the number of bytes in tV["alpha"] is not tV["width"] * tV["height"] then
            throw "the snapshots are" && tH["width"] & "x" & tH["height"] && "and" \
                  && tV["width"] & "x" & tV["height"]
         end if
         put tPosition & comma & tEnabled & comma & tH["width"] * tH["height"] \
               & comma & _DifferencesOnItsSide(tH, tV) & return after tResults
      end repeat
   end repeat
   delete scrollbar "H"
   delete scrollbar "V"
   delete the last char of tResults
   return tResults
end _CompareOnItsSide

-- How far, in pixels, the middle of a vertical slider's thumb pLength
-- pixels long lands from the pointer after a middle click (button 2) at
-- each of the points pYs down it, on a slider 26 pixels wide and 200
-- long: the farthest. The thumb's top travels 200 - pLength pixels, as
-- far down them as its thumbPosition is through the slider's values,
-- and its middle is pLength / 2 below its top
private function _MiddleClickMiss pLength, pYs
   local tY, tMiddle, tMiss
   _CreateScale "V", "0,40,26,240"
   -- (the thumbPosition is rounded by the scrollbar's numberFormat)
   set the numberFormat of scrollbar "V" to "0.000"
   put 0 into tMiss
   repeat for each item tY in pYs
      set the thumbPosition of scrollbar "V" to 0
      click button 2 at 13, tY
      put 40 + (200 - pLength) * the thumbPosition of scrollbar "V" / 100 \
            + pLength / 2 into tMiddle
      TestDiagnostic "a middle click at" && tY & ": thumbPosition" \
            && the thumbPosition of scrollbar "V" & ", the thumb's middle at" && tMiddle
      put max(tMiss, abs(tMiddle - tY)) into tMiss
   end repeat
   delete scrollbar "V"
   return tMiss
end _MiddleClickMiss

on TestWebVerticalSliderIsTheHorizontalOneOnItsSide
   local tResults, tLine
   TestSkipIfNot "platform", "HTML5"

   -- What the fix rests on: no theme draws the web's sliders, and its
   -- look is Windows
   TestAssert "the web engine's look is Windows", the lookAndFeel is "Windows 95"

   create stack "ScaleTest"
   set the defaultStack to "ScaleTest"
   -- 26 pixels is a whole Windows slider; at 16 its thumb is smaller.
   -- The drawing is the same, point for point (each line and corner of
   -- the vertical one is the horizontal one's on its side), so only the
   -- pixels along the edges of the thumb's slanted sides may differ, as
   -- the rasterizer fills them: a fiftieth of the pixels is allowed for
   -- them. In the older look the vertical one's trough alone covered
   -- most of its pixels.
   repeat for each item tAcross in "26,16"
      put _CompareOnItsSide(tAcross, "0,30,100") into tResults
      repeat for each line tLine in tResults
         TestDiagnostic tAcross && "pixels across, at" && item 1 of tLine \
               & ", enabled" && item 2 of tLine & ":" && item 4 of tLine \
               && "of" && item 3 of tLine && "pixels differ"
         TestAssert "a vertical slider" && tAcross && "pixels wide at" && item 1 of tLine \
               & comma && "enabled" && item 2 of tLine & comma \
               && "is the horizontal one on its side", \
               item 4 of tLine <= item 3 of tLine div 50
      end repeat
   end repeat
   delete stack "ScaleTest"
end TestWebVerticalSliderIsTheHorizontalOneOnItsSide

on TestWebVerticalSliderMiddleClick
   local tMiss
   TestSkipIfNot "platform", "HTML5"
   TestSkipIfNot "ui"

   -- A middle click puts the middle of the thumb at the pointer, as it
   -- put the older look's 30-pixel thumb's; on a slider 26 pixels wide
   -- the thumb is 11 pixels long
   create stack "ScaleTest"
   set the defaultStack to "ScaleTest"
   put _MiddleClickMiss(11, "90,140,200") into tMiss
   delete stack "ScaleTest"
   TestAssert "a middle click puts the middle of the thumb at the pointer", tMiss <= 1
end TestWebVerticalSliderMiddleClick

on TestDesktopVerticalSliderAsBefore
   local tLook, tResults, tLine
   TestSkipIf "platform", "HTML5"

   -- On the desktop the engine draws sliders itself in a look set by
   -- script; in the Windows look a vertical slider is drawn as before,
   -- with its trough, not as the horizontal one on its side
   put the lookAndFeel into tLook
   set the lookAndFeel to "Windows 95"
   create stack "ScaleTest"
   set the defaultStack to "ScaleTest"
   put _CompareOnItsSide(26, "30") into tResults
   delete stack "ScaleTest"
   set the lookAndFeel to tLook
   repeat for each line tLine in tResults
      TestDiagnostic "at" && item 1 of tLine & ", enabled" && item 2 of tLine & ":" \
            && item 4 of tLine && "of" && item 3 of tLine && "pixels differ"
   end repeat
   -- Enabled, the trough is drawn
   TestAssert "a vertical slider in the Windows look is drawn as before", \
         item 4 of line 1 of tResults > item 3 of line 1 of tResults div 4
end TestDesktopVerticalSliderAsBefore
