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
-- Selector is left out of its list like the IDE's other stacks, and so is
-- the browser itself; its names (links) read on a dark window and, in a
-- darker grey than its own, on a light one; and its lists are in bigger
-- text.

constant kStack = "TestAppBrowserStack"
constant kBrowser = "App Browser"
constant kPluginLinks = "127,127,127"
constant kLightLinks = "64,64,64"
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

-- The App Browser plugin is one of the IDE's stacks, as it was when it was
-- the stack revApplicationOverview: it leaves itself out of its own list
-- (and the IDE's other lists of stacks). Until rc.6.17 it listed itself
-- (seen in the everyday check with #364 in). A user's stack of that name
-- is the user's
on TestAppBrowserIsAnIDEStack
   if kBrowser is among the lines of the openStacks then
      close stack kBrowser
   end if
   if kBrowser is among the lines of the mainStacks then
      delete stack kBrowser
   end if
   create stack kBrowser
   TestAssert "a user's stack named App Browser is not taken for the IDE's", \
         not revStackNameIsIDEStack(kBrowser)
   delete stack kBrowser

   create stack kStack
   __OpenBrowser
   TestAssert "the App Browser plugin is one of the IDE's stacks", revStackNameIsIDEStack(kBrowser)
   TestAssert "lists of stacks leave the App Browser out", \
         revFilterStacksList(kBrowser & return & kStack) is kStack
   TestAssert "the App Browser does not list itself", kBrowser is not among the lines of __ListedStacks()
   TestAssert "the App Browser lists the user's stack", kStack is among the lines of __ListedStacks()
end TestAppBrowserIsAnIDEStack

on TestAppBrowserLinksReadOnDark
   __OpenBrowser
   TestAssert "the App Browser opens with dark grey links when the IDE is light", \
         revIDEAppearanceIsDark() or the linkColor of stack kBrowser is kLightLinks

   revIDEAppBrowserAppearance true
   TestAssert "dark: the App Browser's links are light grey", \
         the linkColor of stack kBrowser is kDarkLinks
   TestAssert "dark: the plugin is not marked as edited", not revIDEStackIsEdited(kBrowser)

   revIDEAppBrowserAppearance false
   TestAssert "light: the App Browser's links are dark grey again", \
         the linkColor of stack kBrowser is kLightLinks
   revIDEAppBrowserAppearance false
   TestAssert "light twice: still dark grey", the linkColor of stack kBrowser is kLightLinks

   -- the plugin's own mid grey (4 to 1 on white) is made dark grey too,
   -- and light grey on a dark window
   set the linkColor of stack kBrowser to kPluginLinks
   revIDEAppBrowserAppearance false
   TestAssert "light: the plugin's own mid grey becomes dark grey", \
         the linkColor of stack kBrowser is kLightLinks
   set the linkColor of stack kBrowser to kPluginLinks
   revIDEAppBrowserAppearance true
   TestAssert "dark: the plugin's own mid grey becomes light grey", \
         the linkColor of stack kBrowser is kDarkLinks
   TestAssert "the plugin is still not marked as edited", not revIDEStackIsEdited(kBrowser)
end TestAppBrowserLinksReadOnDark

-- richmond62 asked for larger text in the Application Browser
-- (openxtalk.org p=26048): its lists were in 11 points
on TestAppBrowserTextIsBigger
   local tField, tCard
   __OpenBrowser
   repeat for each item tField in "Cards,Controls"
      TestAssert "the App Browser's" && tField && "list is in 13 points", \
            the textSize of field tField of card 1 of stack kBrowser is 13
      TestAssert "its rows are still 22 pixels high", \
            the textHeight of field tField of card 1 of stack kBrowser is 22
   end repeat
   TestAssert "the audio clips list is in 13 points", \
         the textSize of field "AudioClips" of card "Audioclips" of stack kBrowser is 13
   TestAssert "the video clips list is in 13 points", \
         the textSize of field "Videoclips" of card "VideoClips" of stack kBrowser is 13
   TestAssert "the columns are measured in 13 points too", \
         the effective textSize of field "measure width" of card 1 of stack kBrowser is 13
   TestAssert "the plugin is not marked as edited", not revIDEStackIsEdited(kBrowser)

   -- a size set by hand is kept, and opening it again changes nothing
   set the textSize of field "Controls" of card 1 of stack kBrowser to 15
   revIDEAppBrowserText kBrowser
   TestAssert "a list's size set by hand is kept", \
         the textSize of field "Controls" of card 1 of stack kBrowser is 15
   set the textSize of field "Controls" of card 1 of stack kBrowser to 13
   set the textHeight of field "Controls" of card 1 of stack kBrowser to 22
   revIDEAppBrowserText kBrowser
   TestAssert "a second time, the lists stay in 13 points", \
         the textSize of field "Cards" of card 1 of stack kBrowser is 13 and \
         the textHeight of field "Cards" of card 1 of stack kBrowser is 22

   -- a user's stack of that name is left alone
   close stack kBrowser
   create stack "OXT Not The App Browser"
   set the defaultStack to "OXT Not The App Browser"
   create field "Cards"
   set the textSize of field "Cards" of stack "OXT Not The App Browser" to 11
   revIDEAppBrowserText "OXT Not The App Browser"
   TestAssert "another stack's 11-point field is left as it is", \
         the textSize of field "Cards" of stack "OXT Not The App Browser" is 11
   delete stack "OXT Not The App Browser"
end TestAppBrowserTextIsBigger

on TestAppBrowserKeepsAChosenLinkColor
   __OpenBrowser
   set the linkColor of stack kBrowser to "1,2,3"
   revIDEAppBrowserAppearance true
   TestAssert "dark: a link colour set by hand is kept", the linkColor of stack kBrowser is "1,2,3"
   revIDEAppBrowserAppearance false
   TestAssert "light: a link colour set by hand is kept", the linkColor of stack kBrowser is "1,2,3"
end TestAppBrowserKeepsAChosenLinkColor
