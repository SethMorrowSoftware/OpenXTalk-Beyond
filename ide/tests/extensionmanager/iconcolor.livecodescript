script "IDEExtensionManagerIconColor"
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

-- OXT-Beyond: an extension's icon on its Extension Manager row. The row
-- template's purple (96,87,127) could not be seen on the dark selected row
-- (bwmilby, forum, 2026-11-09, on the Mac): in the dark appearance it is
-- lightened, keeping its hue; in the light appearance it is as it was.

on TestTeardown
   local tStack
   put revIDEPaletteToStackName("extension manager") into tStack
   if tStack is not empty and there is a stack tStack then close stack tStack
end TestTeardown

on TestIconColor
   local tStack, tCard, tTemplate, tDark, tHilite
   put revIDEPaletteToStackName("extension manager") into tStack
   revIDEOpenPalette "extension manager"
   wait 500 milliseconds with messages
   TestAssert "the Extension Manager is open", tStack is not empty and there is a stack tStack
   put the long id of card "list" of stack tStack into tCard

   dispatch function "extensionsIconColor" to tCard with "96,87,127", false
   TestAssert "the light appearance keeps the template's colour", the result is "96,87,127"
   dispatch function "extensionsIconColor" to tCard with "96,87,127", true
   put the result into tDark
   TestDiagnostic "dark:" && tDark
   TestAssert "the dark appearance lightens the template's colour", tDark is "191,188,204"
   -- seen on the dark rows and on the Mac's dark selected row (3 to 1,
   -- the least for a graphic); the template's own was 1 to 1 on it
   TestAssert "seen on the dark row", __Contrast(tDark, "30,30,30") >= 3
   TestAssert "seen on the dark alternate row", __Contrast(tDark, "42,42,42") >= 3
   dispatch function "extensionsHiliteColor" to tCard with "226,238,185", true
   put the result into tHilite
   TestAssert "seen on the Mac's dark selected row", __Contrast(tDark, tHilite) >= 3
   TestAssert "the template's own was not", __Contrast("96,87,127", tHilite) < 1.5
   dispatch function "extensionsIconColor" to tCard with "purple", true
   TestAssert "a colour name is left as it is", the result is "purple"
   dispatch function "extensionsIconColor" to tCard with empty, true
   TestAssert "no colour is left as it is", the result is empty

   -- and the rows use it, in the appearance the test runs in
   put the foregroundColor of widget "svgicon" of group "extensionRow" of card "templates" of stack tStack into tTemplate
   TestDiagnostic "template:" && tTemplate && "dark:" && revIDEAppearanceIsDark()
   dispatch function "extensionsIconColor" to tCard with tTemplate, revIDEAppearanceIsDark()
   TestAssert "the first row's icon follows the appearance", \
         __FirstRowIconColor(tStack) is the result
end TestIconColor

private function __FirstRowIconColor pStack
   local tGroup, tC
   put the long id of group "extensionList" of card "list" of stack pStack into tGroup
   repeat with tC = 1 to the number of controls of tGroup
      if word 1 of the name of control tC of tGroup is "widget" and the short name of control tC of tGroup is "svgicon" then
         return the foregroundColor of control tC of tGroup
      end if
   end repeat
   return "no row"
end __FirstRowIconColor

private function __Luminance pRGB
   local tLuminance, tChannel, tValue
   put 0 into tLuminance
   repeat with tChannel = 1 to 3
      put item tChannel of pRGB / 255 into tValue
      if tValue <= 0.03928 then
         put tValue / 12.92 into tValue
      else
         put ((tValue + 0.055) / 1.055) ^ 2.4 into tValue
      end if
      add tValue * item tChannel of "0.2126,0.7152,0.0722" to tLuminance
   end repeat
   return tLuminance
end __Luminance

private function __Contrast pA, pB
   local tA, tB
   if the number of items of pA is not 3 or the number of items of pB is not 3 then return 0
   put __Luminance(pA) + 0.05 into tA
   put __Luminance(pB) + 0.05 into tB
   return max(tA, tB) / min(tA, tB)
end __Contrast
