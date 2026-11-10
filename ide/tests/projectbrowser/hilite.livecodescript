script "ProjectBrowserHilite"
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

-- OXT-Beyond: the colour of a selected Project Browser row's names
-- (revIDEHilitedTextColor). In the web IDE, and on macOS and Windows, they
-- are white on the blue hilite, as LiveCode drew them: OpenXTalk made them
-- the accentColor, a blue on each, and they could hardly be read on the
-- blue hilite (littlenemo, openxtalk.org p=26169, for the web; bwmilby,
-- p=26171, on the Mac). On a light hilite, as the grey of a list that does
-- not have the focus, they are black. Linux answers as before: black or
-- white, whichever stands out more on the GTK theme's selection colour.

constant kDimmed = "212,212,212"

on TestHilitedNamesAreWhiteOnTheWeb
   TestAssert "web: white on the Project Browser's hilite", \
         revIDEHilitedTextColor(revIDEColor("dataView_hiliteColor"), true) is "255,255,255"
   TestAssert "web: white on its alternate hilite", \
         revIDEHilitedTextColor(revIDEColor("dataView_alternateHiliteColor"), true) is "255,255,255"
   TestAssert "web: black on the grey of a list without the focus", revIDEHilitedTextColor(kDimmed, true) is "0,0,0"
   TestAssert "web: black on a light hilite", revIDEHilitedTextColor("255,221,0", true) is "0,0,0"
   TestAssert "web: white for a colour given by name", revIDEHilitedTextColor("blue", true) is "255,255,255"
end TestHilitedNamesAreWhiteOnTheWeb

on TestHilitedNamesAreWhiteOnMacAndWindows
   local tPlatform
   repeat for each item tPlatform in "MacOS,Win32"
      TestAssert tPlatform & ": white on the Project Browser's hilite, as LiveCode drew them", \
            revIDEHilitedTextColor(revIDEColor("dataView_hiliteColor"), false, tPlatform) is "255,255,255"
      TestAssert tPlatform & ": white on its alternate hilite", \
            revIDEHilitedTextColor(revIDEColor("dataView_alternateHiliteColor"), false, tPlatform) is "255,255,255"
      TestAssert tPlatform & ": white on a dark hilite", \
            revIDEHilitedTextColor("0,99,225", false, tPlatform) is "255,255,255"
      TestAssert tPlatform & ": black on the grey of a list without the focus", \
            revIDEHilitedTextColor(kDimmed, false, tPlatform) is "0,0,0"
      TestAssert tPlatform & ": a colour given by name: as before", \
            revIDEHilitedTextColor("blue", false, tPlatform) is revIDEColor("dataView_TextHiliteColor")
   end repeat
end TestHilitedNamesAreWhiteOnMacAndWindows

on TestHilitedNamesOnLinuxAreAsBefore
   TestAssert "Linux: black on a light hilite", revIDEHilitedTextColor("255,221,0", false, "Linux") is "0,0,0"
   TestAssert "Linux: white on a dark one", revIDEHilitedTextColor("119,33,111", false, "Linux") is "255,255,255"
   TestAssert "Linux: black on the Project Browser's hilite", \
         revIDEHilitedTextColor(revIDEColor("dataView_hiliteColor"), false, "Linux") is "0,0,0"
   TestAssert "Linux: a colour given by name: as before", \
         revIDEHilitedTextColor("blue", false, "Linux") is revIDEColor("dataView_TextHiliteColor")
end TestHilitedNamesOnLinuxAreAsBefore

on TestHilitedNamesHereAnswerForThisPlatform
   if not revEnvironmentIsWeb() then
      TestAssert "with no pWeb and no pPlatform, this desktop answers for itself", \
            revIDEHilitedTextColor("48,160,209") is revIDEHilitedTextColor("48,160,209", false, the platform)
   end if
end TestHilitedNamesHereAnswerForThisPlatform

-- Whatever the platform, a selected row's names can be read on the
-- hilites the Project Browser draws: its own blue and its alternate, and
-- the grey of a list without the focus (2.9 to 1 at least, the white of
-- LiveCode's rows on its blue)
on TestHilitedNamesCanBeRead
   local tPlatform, tHilite, tText
   repeat for each item tPlatform in "MacOS,Win32,Linux,web"
      repeat for each item tHilite in "dataView_hiliteColor,dataView_alternateHiliteColor,dimmed"
         if tHilite is "dimmed" then
            put kDimmed into tHilite
         else
            put revIDEColor(tHilite) into tHilite
         end if
         put revIDEHilitedTextColor(tHilite, tPlatform is "web", tPlatform) into tText
         TestAssert tPlatform & ":" && tText && "on" && tHilite && "can be read", __Contrast(tHilite, tText) >= 2.9
      end repeat
   end repeat
end TestHilitedNamesCanBeRead

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
