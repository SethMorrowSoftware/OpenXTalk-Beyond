script "AppBrowserUpdates"
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

-- OXT-Beyond: the Application Browser (the App Browser plugin) told of the
-- IDE's changes. The back and front scripts sent them to the stack
-- "revApplicationOverview", the browser's old name, so the plugin heard of
-- no new stack and no stack removed until Refresh. The IDE's own File
-- Selector is left out of its list like the IDE's other stacks, and its
-- names (links) read on a dark window while a light one is as before.

constant kStack = "TestAppBrowserStack"
constant kBrowser = "App Browser"
constant kLightLinks = "127,127,127"
constant kDarkLinks = "208,208,208"

local sCloseNoWarn, sFolder, sBrowserWasOpen, sLinkColor, sFileSelectorLoaded

on TestSetup
   -- So that Close and Remove From Memory asks nothing
   put the cCloseNoWarn of stack "revPreferences" into sCloseNoWarn
   set the cCloseNoWarn of stack "revPreferences" to true
   put specialFolderPath("temporary") & slash & "oxt-app-browser-" & \
         the milliseconds into sFolder
   create folder sFolder
   put kBrowser is among the lines of the openStacks into sBrowserWasOpen
   put empty into sLinkColor
   put "File Selector" is among the lines of the mainStacks into sFileSelectorLoaded
end TestSetup

on TestTeardown
   set the cCloseNoWarn of stack "revPreferences" to sCloseNoWarn
   if kStack is among the lines of the mainStacks then
      revIDESetUnedited kStack
      delete stack kStack
   end if
   if there is a file (sFolder & slash & kStack & ".oxtstack") then
      delete file (sFolder & slash & kStack & ".oxtstack")
   end if
   delete folder sFolder
   if kBrowser is among the lines of the openStacks then
      if sLinkColor is not empty then
         set the linkColor of stack kBrowser to sLinkColor
      end if
      if not sBrowserWasOpen then
         close stack kBrowser
      end if
   end if
   if not sFileSelectorLoaded and "File Selector" is among the lines of the mainStacks then
      delete stack "File Selector"
   end if
end TestTeardown

private command __OpenBrowser
   if kBrowser is not among the lines of the openStacks then
      revIDEOpenPlugin kBrowser
   end if
   wait 500 milliseconds with messages
   put the linkColor of stack kBrowser into sLinkColor
end __OpenBrowser

-- The stack names in the browser's tree: a stack's line has no card
-- number (item 2), its name is item 1
private function __ListedStacks
   local tLine, tStacks
   if kBrowser is not among the lines of the openStacks then
      return empty
   end if
   set the itemDelimiter to tab
   repeat for each line tLine in field "Cards" of group "Cards" of card 1 of stack kBrowser
      if word 1 to -1 of item 2 of tLine is empty and word 1 to -1 of item 1 of tLine is not empty then
         put word 1 to -1 of item 1 of tLine & return after tStacks
      end if
   end repeat
   return line 1 to -1 of tStacks
end __ListedStacks

-- The stack kStack, saved, with the browser opened after it, so that the
-- browser lists it from the start
private command __ListedSavedStack
   create stack kStack
   set the defaultStack to kStack
   create button "B1"
   save stack kStack as (sFolder & slash & kStack & ".oxtstack")
   revIDESetUnedited kStack
   __OpenBrowser
end __ListedSavedStack

on TestRemovedStackLeavesAppBrowser
   __ListedSavedStack
   TestAssert "the App Browser lists the stack", kStack is among the lines of __ListedStacks()

   revIDECloseStack the long id of stack kStack, true
   wait 200 milliseconds with messages
   TestAssert "the stack is removed from memory", kStack is not among the lines of the mainStacks
   TestAssert "the App Browser no longer lists the removed stack, without Refresh", \
         kStack is not among the lines of __ListedStacks()
end TestRemovedStackLeavesAppBrowser

on TestNewStackJoinsAppBrowser
   __OpenBrowser
   TestAssert "the App Browser does not list the stack yet", \
         kStack is not among the lines of __ListedStacks()

   create stack kStack
   wait 200 milliseconds with messages
   TestAssert "the App Browser lists the new stack, without Refresh", \
         kStack is among the lines of __ListedStacks()
end TestNewStackJoinsAppBrowser

on TestRenamedStackInAppBrowser
   __ListedSavedStack
   set the name of stack kStack to (kStack & "2")
   wait 200 milliseconds with messages
   local tListed
   put __ListedStacks() into tListed
   set the name of stack (kStack & "2") to kStack
   TestAssert "the App Browser lists the stack under its new name, without Refresh", \
         (kStack & "2") is among the lines of tListed and kStack is not among the lines of tListed
end TestRenamedStackInAppBrowser

on TestOnlyAnOpenAppBrowserIsTold
   if kBrowser is among the lines of the openStacks then
      close stack kBrowser
   end if
   TestAssert "no Application Browser is named when none is open", \
         revIDEAppBrowserStack() is empty
   __OpenBrowser
   TestAssert "the open App Browser plugin is named", revIDEAppBrowserStack() is kBrowser
end TestOnlyAnOpenAppBrowserIsTold

on TestFileSelectorIsAnIDEStack
   local tPath
   if "File Selector" is among the lines of the mainStacks then
      delete stack "File Selector"
   end if
   -- A user's stack of that name is the user's
   create stack "File Selector"
   TestAssert "a user's stack named File Selector is not taken for the IDE's", \
         not revStackNameIsIDEStack("File Selector")
   delete stack "File Selector"

   -- Toolset/palettes/revfileselector.rev, beside Toolset/libraries
   put the effective filename of stack "revcommonlibrary" into tPath
   set the itemDelimiter to slash
   put "palettes/revfileselector.rev" into item -2 to -1 of tPath
   get the long id of stack tPath
   TestAssert "the IDE's File Selector is loaded", "File Selector" is among the lines of the mainStacks
   TestAssert "the IDE's File Selector is one of the IDE's stacks", \
         revStackNameIsIDEStack("File Selector")
   create stack kStack
   TestAssert "lists of stacks leave the IDE's File Selector out", \
         revFilterStacksList("File Selector" & return & kStack) is kStack
end TestFileSelectorIsAnIDEStack

on TestAppBrowserLinksReadOnDark
   __OpenBrowser
   TestAssert "the App Browser opens with its own grey links when the IDE is light", \
         revIDEAppearanceIsDark() or the linkColor of stack kBrowser is kLightLinks

   revIDEAppBrowserAppearance true
   TestAssert "dark: the App Browser's links are light grey", \
         the linkColor of stack kBrowser is kDarkLinks
   TestAssert "dark: the plugin is not marked as edited", not revIDEStackIsEdited(kBrowser)

   revIDEAppBrowserAppearance false
   TestAssert "light: the App Browser's links are its own grey again", \
         the linkColor of stack kBrowser is kLightLinks
   revIDEAppBrowserAppearance false
   TestAssert "light twice: still its own grey", the linkColor of stack kBrowser is kLightLinks
end TestAppBrowserLinksReadOnDark

on TestAppBrowserKeepsAChosenLinkColor
   __OpenBrowser
   set the linkColor of stack kBrowser to "1,2,3"
   revIDEAppBrowserAppearance true
   TestAssert "dark: a link colour set by hand is kept", the linkColor of stack kBrowser is "1,2,3"
   revIDEAppBrowserAppearance false
   TestAssert "light: a link colour set by hand is kept", the linkColor of stack kBrowser is "1,2,3"
end TestAppBrowserKeepsAChosenLinkColor
