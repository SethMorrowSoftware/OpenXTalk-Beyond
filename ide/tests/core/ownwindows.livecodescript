script "IDEOwnWindows"
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

-- OXT-Beyond: the IDE's own stacks from OpenXTalk Lite whose names do not
-- begin with "rev" are the IDE's: the Card Navigator (Tools > Card
-- Navigator, the stack "Card Navigator" of Toolset/palettes/
-- navigatorIDE.oxtstack), and the lessons and the guides (the stacks
-- "userguides" and "allguides" of Toolset/palettes/userguides, which Learn
-- and Home read their pages from). Until 0.2.7-rc.6.17 the rest of the IDE
-- took them for the user's stacks (OpenXTalkPaul, openxtalk.org p=26111,
-- for the Card Navigator; the IDE tour's ide-stacks step, for the guides):
-- the lists of the user's stacks built on revFilterStacksList (the App
-- Browser's, Standalone Settings') showed them. A user's stack of the same
-- name is still the user's.

constant kNavigator = "Card Navigator"
constant kGuides = "userguides,allguides"

local sLoaded, sWasOpen

on TestSetup
   put the mainStacks into sLoaded
   put kNavigator is among the lines of the openStacks into sWasOpen
end TestSetup

on TestTeardown
   local tStack
   if kNavigator is among the lines of the openStacks and not sWasOpen then
      close stack kNavigator
   end if
   repeat for each item tStack in kNavigator & comma & kGuides
      if tStack is among the lines of the mainStacks and tStack is not among the lines of sLoaded then
         if tStack is kNavigator then
            -- (it looks at the top stack again every 50 ticks while it
            -- is in memory)
            __CancelUpdates
         end if
         delete stack tStack
      end if
   end repeat
end TestTeardown

private command __CancelUpdates
   local tLine
   repeat for each line tLine in the pendingMessages
      if item 3 of tLine is "hNavigatorUpdate" then
         cancel item 1 of tLine
      end if
   end repeat
end __CancelUpdates

on TestCardNavigatorIsAnIDEStack
   if kNavigator is not among the lines of sLoaded then
      create stack kNavigator
      TestAssert "a user's stack named Card Navigator is not taken for the IDE's", \
            not revStackNameIsIDEStack(kNavigator)
      delete stack kNavigator
   end if

   -- as Tools > Card Navigator opens it
   send "tOpenNavigator" to stack "revMenuBar"
   wait 200 milliseconds with messages
   TestAssert "Tools > Card Navigator opens the Card Navigator", \
         kNavigator is among the lines of the openStacks
   TestAssert "the Card Navigator is one of the IDE's stacks", revStackNameIsIDEStack(kNavigator)
   TestAssert "lists of the user's stacks leave the Card Navigator out", \
         kNavigator is not among the lines of revFilterStacksList(the mainStacks)
end TestCardNavigatorIsAnIDEStack

on TestGuidesAreIDEStacks
   local tStack, tPath
   repeat for each item tStack in kGuides
      if tStack is not among the lines of sLoaded then
         create stack tStack
         TestAssert "a user's stack named" && tStack && "is not taken for the IDE's", \
               not revStackNameIsIDEStack(tStack)
         delete stack tStack
      end if

      -- loaded as Learn loads it, to read its pages' names: naming its
      -- file loads it without opening it
      put revEnvironmentToolsetPath() & "/palettes/userguides/" & tStack & ".oxtstack" into tPath
      TestAssert tStack && "is in the Toolset", there is a file tPath
      get the number of cards of stack tPath
      TestAssert tStack && "is loaded", tStack is among the lines of the mainStacks
      TestAssert tStack && "is one of the IDE's stacks", revStackNameIsIDEStack(tStack)
      TestAssert "lists of the user's stacks leave" && tStack && "out", \
            tStack is not among the lines of revFilterStacksList(the mainStacks)
   end repeat
end TestGuidesAreIDEStacks
