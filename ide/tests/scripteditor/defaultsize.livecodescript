script "ScriptEditorDefaultSize"
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

-- OXT-Beyond: a Script Editor with no size kept from before opens in the
-- middle 40% of its screen's width and 60% of its height, but no smaller
-- than its minWidth and minHeight, as far as the screen allows. On a screen
-- under 1250 wide the 40% was narrower than the editor's minWidth (500):
-- the engine kept that rect, but Windows sometimes made the window its
-- minimum width as it showed, and the IDE kept that, so the editor opened
-- 410 wide one time and 500 the next on a 1024 screen
-- (revIDEPositionPaletteDefault).

-- A stack named as a Script Editor is, so the IDE places it as one, with
-- the minimum sizes given
constant kStack = "revNewScriptEditor OXTDefaultSizeProbe"

on TestTeardown
   if there is a stack kStack then delete stack kStack
end TestTeardown

private function __Probe pMinWidth, pMinHeight
   if there is a stack kStack then delete stack kStack
   create invisible stack kStack
   set the minWidth of stack kStack to pMinWidth
   set the minHeight of stack kStack to pMinHeight
   revIDEPositionPaletteDefault kStack
   return the rect of stack kStack
end __Probe

private function __Screen
   if there is not a stack kStack then create invisible stack kStack
   return revIDEStackScreenRect(kStack, true)
end __Screen

-- Where the screen is wide enough, the middle 40% and 60%, as before
on TestDefaultSizeAsBefore
   local tRect, tScreen, tW, tH
   put __Probe(100, 100) into tRect
   put __Screen() into tScreen
   put item 3 of tScreen - item 1 of tScreen into tW
   put item 4 of tScreen - item 2 of tScreen into tH
   TestDiagnostic "screen" && tScreen && "rect" && tRect
   TestAssert "the width is 40% of the screen's", \
         abs((item 3 of tRect - item 1 of tRect) - tW * 0.4) <= 1
   TestAssert "the height is 60% of the screen's", \
         abs((item 4 of tRect - item 2 of tRect) - tH * 0.6) <= 1
   TestAssert "the left is 30% across", abs(item 1 of tRect - (item 1 of tScreen + tW * 0.3)) <= 1
   TestAssert "the top is 20% down", abs(item 2 of tRect - (item 2 of tScreen + tH * 0.2)) <= 1
end TestDefaultSizeAsBefore

-- A minWidth and minHeight above the 40% and 60% are kept
on TestDefaultSizeNotBelowMinimum
   local tRect, tScreen, tW, tH, tMinW, tMinH
   put __Screen() into tScreen
   put item 3 of tScreen - item 1 of tScreen into tW
   put item 4 of tScreen - item 2 of tScreen into tH
   put round(tW * 0.5) into tMinW
   put round(tH * 0.7) into tMinH
   put __Probe(tMinW, tMinH) into tRect
   TestDiagnostic "screen" && tScreen && "minimum" && tMinW & "," & tMinH && "rect" && tRect
   TestAssert "the width is the minWidth", item 3 of tRect - item 1 of tRect = tMinW
   TestAssert "the height is the minHeight", item 4 of tRect - item 2 of tRect = tMinH
   TestAssert "the window is on the screen", item 1 of tRect >= item 1 of tScreen and \
         item 2 of tRect >= item 2 of tScreen and item 3 of tRect <= item 3 of tScreen and \
         item 4 of tRect <= item 4 of tScreen
end TestDefaultSizeNotBelowMinimum

-- A minimum larger than the screen gives the whole screen, no more
on TestDefaultSizeNoLargerThanScreen
   local tRect, tScreen
   put __Screen() into tScreen
   put __Probe(item 3 of tScreen - item 1 of tScreen + 200, item 4 of tScreen - item 2 of tScreen + 200) into tRect
   TestDiagnostic "screen" && tScreen && "rect" && tRect
   TestAssert "the window is the screen's working area", tRect is tScreen
end TestDefaultSizeNoLargerThanScreen
