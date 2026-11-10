script "IDEExtensionManagerHiliteColor"
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

-- OXT-Beyond: the Extension Manager's selected row is drawn in the hilite
-- colour under a white name in the dark appearance. The edition's light
-- selection colour left the name unreadable there (bwmilby, forum,
-- 2026-11-07, on the Mac): it is darkened, keeping its hue; in the light
-- appearance it is as it was.

on TestTeardown
   local tStack
   put revIDEPaletteToStackName("extension manager") into tStack
   if tStack is not empty and there is a stack tStack then close stack tStack
end TestTeardown

on TestHiliteColor
   local tStack, tCard, tLight, tDark, tSum, tSelected, tExpected
   put revIDEPaletteToStackName("extension manager") into tStack
   revIDEOpenPalette "extension manager"
   wait 500 milliseconds with messages
   TestAssert "the Extension Manager is open", tStack is not empty and there is a stack tStack
   put the long id of card "list" of stack tStack into tCard

   put "240,200,180" into tLight
   dispatch function "extensionsHiliteColor" to tCard with tLight, false
   TestAssert "the light appearance keeps the selection colour", the result is tLight
   dispatch function "extensionsHiliteColor" to tCard with tLight, true
   put the result into tDark
   TestDiagnostic "dark:" && tDark
   TestAssert "the dark appearance darkens the selection colour", tDark is "96,80,72"
   put item 1 of tDark + item 2 of tDark + item 3 of tDark into tSum
   -- the white name readable on it, and apart from the dark rows (30, 42)
   TestAssert "white is readable on the dark selection colour", 255 - tSum / 3 > 150
   TestAssert "the dark rows and the dark selection colour differ", tSum / 3 - 42 > 25
   dispatch function "extensionsHiliteColor" to tCard with "226,238,185", true
   TestAssert "the Mac edition's selection colour darkens too", the result is "90,95,74"
   dispatch function "extensionsHiliteColor" to tCard with "red", true
   TestAssert "a colour name is left as it is", the result is "red"

   -- and the list uses it, in the appearance the test runs in
   dispatch function "ideColorGet" to tCard with "pb_line_selected"
   put the result into tSelected
   TestDiagnostic "selection colour:" && tSelected && "dark:" && revIDEAppearanceIsDark()
   dispatch function "extensionsHiliteColor" to tCard with tSelected, revIDEAppearanceIsDark()
   put the result into tExpected
   TestAssert "the list's hilite colour follows the appearance", \
         the viewProp["hilite color"] of group "extensionList" of tCard is tExpected
end TestHiliteColor
