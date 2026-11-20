script "IDEStyleTextShift"
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

-- OXT-Beyond: Text > Superscript and Text > Subscript (ideStyleText). Each
-- is a toggle of its own direction. Up to 0.2.8-dp.2, and in LiveCode
-- Community, either item took any shift off, so Subscript on superscript
-- text had to be chosen twice.

constant kStack = "TestStyleTextShiftStack"

on TestSetup
   create invisible stack kStack
   set the defaultStack to kStack
   create field "Text"
   put "hello world again" into field "Text"
end TestSetup

on TestTeardown
   if there is a stack kStack then delete stack kStack
end TestTeardown

private command __Style pChunk, pWhich
   ideStyleText pChunk && "of field 1", the long id of field "Text" of stack kStack, true, pWhich
end __Style

private function __Shift pChunk
   local tShift
   do "put the textShift of" && pChunk && "of field" && quote & "Text" & quote && "of stack kStack into tShift"
   return tShift
end __Shift

on TestSuperscriptAndSubscriptToggle
   __Style "char 1 to 5", "superscript"
   TestAssert "Superscript raises plain text", __Shift("char 1 to 5") is -4
   __Style "char 1 to 5", "superscript"
   TestAssert "Superscript again takes the shift off", __Shift("char 1 to 5") is 0
   __Style "char 1 to 5", "superscript"
   TestAssert "and a third time raises it again", __Shift("char 1 to 5") is -4
   __Style "char 7 to 11", "subscript"
   TestAssert "Subscript lowers plain text", __Shift("char 7 to 11") is 4
   __Style "char 7 to 11", "subscript"
   TestAssert "Subscript again takes the shift off", __Shift("char 7 to 11") is 0
   TestAssert "text beside it is untouched", __Shift("char 13 to 17") is empty
end TestSuperscriptAndSubscriptToggle

on TestTheOtherItemSwitchesAtOnce
   __Style "char 1 to 5", "superscript"
   __Style "char 1 to 5", "subscript"
   TestAssert "Subscript on superscript text makes it subscript", __Shift("char 1 to 5") is 4
   __Style "char 1 to 5", "superscript"
   TestAssert "Superscript on subscript text makes it superscript", __Shift("char 1 to 5") is -4
end TestTheOtherItemSwitchesAtOnce

on TestAMixedSelectionTakesTheItemsShift
   __Style "char 1 to 5", "superscript"
   __Style "char 7 to 11", "subscript"
   TestAssert "the selection is mixed", __Shift("char 1 to 11") is "mixed"
   __Style "char 1 to 11", "superscript"
   TestAssert "Superscript on a mixed selection raises all of it", __Shift("char 1 to 11") is -4
end TestAMixedSelectionTakesTheItemsShift
