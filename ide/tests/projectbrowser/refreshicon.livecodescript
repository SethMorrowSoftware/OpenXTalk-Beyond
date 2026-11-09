script "ProjectBrowserRefreshIcon"
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

-- OXT-Beyond: the Project Browser's Refresh button shows revIcons'
-- "white-refresh" in the dark appearance and its "dark-refresh" in the
-- light one. The stack's own preOpenStack picks it by the window's colour,
-- which on the Mac stays light in the dark appearance, so the black arrows
-- were left on the dark window (bwmilby, forum, 2026-11-09). On Linux the
-- stack's choice, by the window's colour, is left as it was.

on TestTeardown
   local tStack
   put revIDEPaletteToStackName("project browser") into tStack
   if tStack is not empty and there is a stack tStack then close stack tStack
end TestTeardown

on TestRefreshIconName
   local tStack
   put revIDEPaletteToStackName("project browser") into tStack
   revIDEOpenPalette "project browser"
   wait 500 milliseconds with messages
   TestAssert "the Project Browser is open", tStack is not empty and there is a stack tStack
   dispatch function "pbRefreshIconName" to stack tStack with true
   TestAssert "dark: white arrows", the result is "white-refresh"
   dispatch function "pbRefreshIconName" to stack tStack with false
   TestAssert "light: dark arrows", the result is "dark-refresh"
   dispatch function "pbRefreshIconName" to stack tStack with empty
   TestAssert "no answer: dark arrows, as before", the result is "dark-refresh"
end TestRefreshIconName

on TestRefreshIconFollowsTheAppearance
   local tStack, tIcon, tWant
   if there is not a stack "revIcons" then
      TestSkip "Refresh icon follows the appearance", "no revIcons"
      exit TestRefreshIconFollowsTheAppearance
   end if
   put revIDEPaletteToStackName("project browser") into tStack
   revIDEOpenPalette "project browser"
   wait 500 milliseconds with messages
   put the icon of button "Refresh" of card "list" of stack tStack into tIcon
   TestDiagnostic "icon:" && tIcon && "dark:" && revIDEAppearanceIsDark() && "platform:" && the platform
   if revIDEAppearanceIsDark() then
      put the id of image "white-refresh" of card 1 of stack "revIcons" into tWant
   else
      put the id of image "dark-refresh" of card 1 of stack "revIcons" into tWant
   end if
   if the platform is "Linux" then
      -- the stack's own choice, by the window's colour, as before
      TestAssert "Linux: the Refresh icon is one of revIcons' two", \
            tIcon is the id of image "white-refresh" of card 1 of stack "revIcons" or \
            tIcon is the id of image "dark-refresh" of card 1 of stack "revIcons"
   else
      TestAssert "the Refresh icon follows the appearance", tIcon is tWant
      -- and a switch of appearance sets it again
      set the icon of button "Refresh" of card "list" of stack tStack to 0
      dispatch "ideSystemAppearanceChanged" to stack tStack
      TestAssert "set again on a switch of appearance", \
            the icon of button "Refresh" of card "list" of stack tStack is tWant
   end if
end TestRefreshIconFollowsTheAppearance
