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
-- darker grey than its own, on a light one; its lists are in bigger
-- text; its icons are larger, drawn from SVG; and it is in the Tools menu
-- again.

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
      TestAssert "its rows are 24 pixels high, for the larger icons", \
            the textHeight of field tField of card 1 of stack kBrowser is 24
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
   set the textHeight of field "Controls" of card 1 of stack kBrowser to 24
   revIDEAppBrowserText kBrowser
   TestAssert "a second time, the lists stay in 13 points", \
         the textSize of field "Cards" of card 1 of stack kBrowser is 13 and \
         the textHeight of field "Cards" of card 1 of stack kBrowser is 24
   -- the plugin's own 22, set as it first opens, becomes 24; a row
   -- height set by hand is kept
   set the textHeight of field "Controls" of card 1 of stack kBrowser to 22
   revIDEAppBrowserText kBrowser
   TestAssert "the plugin's own 22-pixel rows become 24", \
         the textHeight of field "Controls" of card 1 of stack kBrowser is 24
   set the textHeight of field "Controls" of card 1 of stack kBrowser to 30
   revIDEAppBrowserText kBrowser
   TestAssert "a row height set by hand is kept", \
         the textHeight of field "Controls" of card 1 of stack kBrowser is 30
   set the textHeight of field "Controls" of card 1 of stack kBrowser to 24

   -- a list that fits in 22-pixel rows but not in 24 gets its scroll
   -- bar when its rows grow (Codex review of #390): without it, its last
   -- rows were cut off with no scroll bar until a resize
   local tRows, tSaved
   put field "Cards" of card 1 of stack kBrowser into tSaved
   -- (as many rows as fit at 22 pixels)
   set the textHeight of field "Cards" of card 1 of stack kBrowser to 22
   set the vScrollbar of field "Cards" of card 1 of stack kBrowser to false
   put "x" into field "Cards" of card 1 of stack kBrowser
   put 1 into tRows
   repeat 200 times
      put return & "x" after field "Cards" of card 1 of stack kBrowser
      if the formattedHeight of field "Cards" of card 1 of stack kBrowser > \
            the height of field "Cards" of card 1 of stack kBrowser then
         delete the last line of field "Cards" of card 1 of stack kBrowser
         exit repeat
      end if
      add 1 to tRows
   end repeat
   TestAssert "the list fits in 22-pixel rows", \
         the formattedHeight of field "Cards" of card 1 of stack kBrowser > 0 and \
         the formattedHeight of field "Cards" of card 1 of stack kBrowser <= \
         the height of field "Cards" of card 1 of stack kBrowser
   revIDEAppBrowserText kBrowser
   TestAssert "in 24-pixel rows it overflows", \
         the formattedHeight of field "Cards" of card 1 of stack kBrowser > \
         the height of field "Cards" of card 1 of stack kBrowser
   TestAssert "and it gets its scroll bar", \
         the vScrollbar of field "Cards" of card 1 of stack kBrowser
   put tSaved into field "Cards" of card 1 of stack kBrowser
   send "revSetVScrollbar the long id of field" && quote & "Cards" & quote && "of card 1 of stack" && \
         quote & kBrowser & quote & ", the long id of group" && quote & "Card Tabs" & quote && \
         "of card 1 of stack" && quote & kBrowser & quote to stack kBrowser

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

-- richmond62 asked for larger icons in the Application Browser
-- (openxtalk.org p=26048): its pictures were bitmaps 9 to 14 points high.
-- Each icon the plugin names is drawn again, larger, in the plugin's own
-- stack, so that its own image is found before any other of that ID
on TestAppBrowserIconsAreLarger
   local tProp, tId, tIds, tSize, tText, tLight
   __OpenBrowser
   repeat for each item tProp in revIDEAppBrowserIconProps()
      put the tProp of stack kBrowser into tId
      TestAssert tProp && "names an image of the plugin's own stack", \
            tId is an integer and there is an image id tId of stack kBrowser
      if not (tId is an integer and there is an image id tId of stack kBrowser) then next repeat
      TestAssert tProp && "is the drawn icon", \
            the short name of image id tId of stack kBrowser is ("oxt" & tProp)
      put revIDEAppBrowserIconSize(tProp) into tSize
      TestAssert tProp && "is" && tSize && "points square", \
            the width of image id tId of stack kBrowser is tSize and \
            the height of image id tId of stack kBrowser is tSize
      TestAssert tProp && "is drawn", the text of image id tId of stack kBrowser is not empty
      put tId & comma after tIds
   end repeat
   TestAssert "a stack, a card and a control are 20 points, the triangles 12", \
         revIDEAppBrowserIconSize("cMainStackIcon") is 20 and revIDEAppBrowserIconSize("cCardIcon") is 20 and \
         revIDEAppBrowserIconSize("cButtonIcon") is 20 and revIDEAppBrowserIconSize("cWindowsInIcon") is 12
   TestAssert "each icon is larger than the plugin's own picture of it was (14 points high at most)", \
         revIDEAppBrowserIconSize("cMainStackIcon") > 14 and revIDEAppBrowserIconSize("cWindowsOutIcon") > 9
   TestAssert "nothing is drawn for an unticked box, as before", \
         "cUnTickIcon" is not among the items of revIDEAppBrowserIconProps()
   TestAssert "the icons are in one hidden group", \
         there is an image ("oxtcMainStackIcon") of group "oxtAppBrowserIcons" of card 1 of stack kBrowser and \
         not the visible of group "oxtAppBrowserIcons" of card 1 of stack kBrowser
   TestAssert "the plugin is not marked as edited", not revIDEStackIsEdited(kBrowser)

   -- drawn again (an appearance change, or opening it again): the same
   -- images, no new ones, inked for the window
   put the text of image id (the cMainStackIcon of stack kBrowser) of stack kBrowser into tLight
   revIDEAppBrowserIcons kBrowser, true
   TestAssert "dark: the same images are drawn again", \
         the cMainStackIcon of stack kBrowser & comma is item 1 of tIds & comma
   TestAssert "dark: they are inked again", \
         the text of image id (the cMainStackIcon of stack kBrowser) of stack kBrowser is not tLight
   TestAssert "dark: no new image is made", \
         the number of images of group "oxtAppBrowserIcons" of card 1 of stack kBrowser is \
         the number of items of tIds
   revIDEAppBrowserAppearance false
   TestAssert "light again: inked as at first", \
         the text of image id (the cMainStackIcon of stack kBrowser) of stack kBrowser is tLight
   TestAssert "light again: no new image is made", \
         the number of images of group "oxtAppBrowserIcons" of card 1 of stack kBrowser is \
         the number of items of tIds
   TestAssert "the plugin is still not marked as edited", not revIDEStackIsEdited(kBrowser)

   -- a user's stack of that name is left alone
   close stack kBrowser
   create stack "OXT Not The App Browser"
   set the cMainStackIcon of stack "OXT Not The App Browser" to 200083
   revIDEAppBrowserIcons "OXT Not The App Browser"
   TestAssert "another stack's icon property is left as it is", \
         the cMainStackIcon of stack "OXT Not The App Browser" is 200083
   TestAssert "and nothing is made in it", \
         the number of images of stack "OXT Not The App Browser" is 0
   delete stack "OXT Not The App Browser"
end TestAppBrowserIconsAreLarger

-- richmond62 asked for the Application Browser back in the Tools menu
-- (openxtalk.org p=26074). It is there beside the Project Browser, checked
-- when it is shown, and it opens and closes the plugin; every item the
-- menu had is still there
on TestAppBrowserInToolsMenu
   local tMenu, tItem
   if kBrowser is among the lines of the openStacks then
      close stack kBrowser
   end if
   dispatch function "revMenubarBuildMenu" to stack "revMenuBar" with "Tools"
   put the result into tMenu
   TestAssert "the Tools menu has Application Browser", tMenu contains "Application Browser"
   repeat for each item tItem in "Browse Tool,Pointer Tool,Tools Palette,Paint and Draw Tools,Project Browser," & \
         "Message Box,Extension Manager,Extension Builder,Menu Builder"
      TestAssert "the Tools menu still has" && tItem, tMenu contains tItem
   end repeat
   TestAssert "Application Browser is right after the Project Browser", \
         lineOffset("Application Browser", tMenu) is lineOffset("Project Browser", tMenu) + 1
   TestAssert "unchecked while the App Browser is closed", \
         "!nApplication Browser" is among the lines of tMenu

   dispatch "revMenubarToolsMenuPick" to stack "revMenuBar" with "Application Browser"
   wait 500 milliseconds with messages
   TestAssert "Tools > Application Browser opens the App Browser plugin", \
         revIDEAppBrowserStack() is kBrowser and the visible of stack kBrowser
   if kBrowser is among the lines of the openStacks then
      put the linkColor of stack kBrowser into sLinkColor
   end if
   dispatch function "revMenubarBuildMenu" to stack "revMenuBar" with "Tools"
   TestAssert "checked while it is shown", "!cApplication Browser" is among the lines of the result

   TestAssert "the open App Browser is marked open in the preferences", \
         the cAppOverview of stack "revPreferences" is true
   dispatch "revMenubarToolsMenuPick" to stack "revMenuBar" with "Application Browser"
   wait 200 milliseconds with messages
   TestAssert "Tools > Application Browser closes it again", revIDEAppBrowserStack() is empty
   -- closed as its close box closes it: the plugin's revAppBrowserFinalise
   -- ran (it keeps the stacks open in its tree, and marks it closed)
   -- (Codex review of #390)
   TestAssert "closing it from the menu runs the plugin's finaliser", \
         the cAppOverview of stack "revPreferences" is false
end TestAppBrowserInToolsMenu

-- littlenemo asked for white names on the selected rows (openxtalk.org
-- p=26169; seth's decision of 2026-11-08: in the web IDE). The plugin's
-- file was saved with cSuspended true, which only Windows clears, so it
-- painted each selected control's, audio clip's and video clip's name
-- black on the blue hilite. In the web IDE it is cleared as the plugin
-- opens; a desktop is left as it was
on TestAppBrowserHilitedNamesOnTheWeb
   local tWas
   __OpenBrowser
   put the cSuspended of stack kBrowser into tWas
   lock messages
   set the cSuspended of stack kBrowser to true
   unlock messages
   revIDEAppBrowserHilitedNames kBrowser, false
   TestAssert "a desktop: cSuspended is left as it is", the cSuspended of stack kBrowser is true
   if not revEnvironmentIsWeb() then
      revIDEAppBrowserHilitedNames kBrowser
      TestAssert "this desktop (no pWeb): cSuspended is left as it is", the cSuspended of stack kBrowser is true
   end if
   revIDEAppBrowserHilitedNames kBrowser, true
   TestAssert "the web IDE: cSuspended is cleared, so selected names are not painted black", \
         the cSuspended of stack kBrowser is false
   TestAssert "the plugin is not marked as edited", not revIDEStackIsEdited(kBrowser)
   lock messages
   set the cSuspended of stack kBrowser to tWas
   unlock messages

   -- a user's stack of that name is left alone
   create stack "OXT Not The App Browser"
   set the cSuspended of stack "OXT Not The App Browser" to true
   revIDEAppBrowserHilitedNames "OXT Not The App Browser", true
   TestAssert "another stack's cSuspended is left as it is", \
         the cSuspended of stack "OXT Not The App Browser" is true
   delete stack "OXT Not The App Browser"
end TestAppBrowserHilitedNamesOnTheWeb
