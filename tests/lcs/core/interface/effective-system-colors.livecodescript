script "CoreInterfaceEffectiveSystemColors"
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

/*
OXT-Beyond: on macOS a stack with no colours of its own reads the Mac's
own colours, as the appearance shows them now (seth's choice 1A of
2026-10-31; bwmilby, openxtalk.org p=25665, p=25668): its card's effective
backgroundColor is light in the light appearance and dark in the dark, its
effective foregroundColor the other way round, and the stack reads what
its card reads. These tests read them in the appearance the tests run in;
a switch between the two while the engine runs is checked by the IDE tour
(tools/ci/ui-tour.livecodescript, the step system-switch), which makes one.
*/

on TestEffectiveSystemColors
   local tStack, tBack, tFore, tDark
   TestSkipIfNot "platform", "MacOS"
   TestSkipIfNot "ui"
   put "EffectiveSystemColors" & the milliseconds into tStack
   create invisible stack tStack
   put the effective backgroundColor of card 1 of stack tStack into tBack
   put the effective foregroundColor of card 1 of stack tStack into tFore
   put the systemAppearance is "dark" into tDark
   TestDiagnostic "the systemAppearance" && the systemAppearance & ": a card's effective backgroundColor" && \
         tBack & ", foregroundColor" && tFore
   TestAssert "the card's effective backgroundColor is a colour", the number of items of tBack is 3
   TestAssert "the card's effective foregroundColor is a colour", the number of items of tFore is 3
   TestAssert "the card's effective backgroundColor is the appearance's", __IsLight(tBack) is not tDark
   TestAssert "the card's effective foregroundColor is the appearance's", __IsLight(tFore) is tDark
   TestAssert "the stack reads its card's backgroundColor", \
         the effective backgroundColor of stack tStack is tBack
   TestAssert "the stack reads its card's foregroundColor", \
         the effective foregroundColor of stack tStack is tFore
   TestAssert "and neither has a colour of its own", \
         the backgroundColor of stack tStack is empty and the backgroundColor of card 1 of stack tStack is empty
   delete stack tStack
end TestEffectiveSystemColors

-- Whether the colour pRGB ("r,g,b") is light: the mean of the three 128
-- or more
private function __IsLight pRGB
   if the number of items of pRGB is not 3 then return empty
   return (item 1 of pRGB + item 2 of pRGB + item 3 of pRGB) / 3 >= 128
end __IsLight
