script "TestSplashScreen"
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

-- The splash moves, on its first status, to the middle of the screen the
-- IDE's menu bar was last on (from HyperXTalk, #442), and stays in the
-- middle of the main screen, as before, when the menu bar has no saved
-- place or that place is on no screen now
-- (ide/Toolset/palettes/splash/revsplashstackbehavior.livecodescript).
--
-- The behaviour runs on a stack of the test's own, with a field "status"
-- as the splash has, and a stand-in for the preferences stack; the screen
-- is whichever the machine has, so a place on it and one off every screen
-- are what is asked about.

constant kStack = "TestSplashScreenStack"
constant kBehavior = "revSplashStackBehavior"

local sFound

on TestSetup
   TestSkipIfNot "ui"
   -- a phone or tablet shows a stack on its one screen, wherever it is put
   TestSkipIfNot "desktop"
   -- The IDE's own preferences are never stood in for
   if there is a stack "revPreferences" then
      throw "SKIP the IDE's preferences are in memory"
   end if
   put there is a stack kBehavior into sFound
   get the long id of stack (TestGetIDERepositoryPath() & "/Toolset/palettes/splash/revsplashstackbehavior.livecodescript")
   create invisible stack "revPreferences"
   __NewSplash
end TestSetup

on TestTeardown
   if there is a stack kStack then delete stack kStack
   if there is a stack "revPreferences" then delete stack "revPreferences"
   if sFound is not true and there is a stack kBehavior then delete stack kBehavior
end TestTeardown

on TestMovesToTheMenubarsScreen
   local tScreen, tRect
   put line 1 of the screenRects into tScreen
   -- a menu bar near the top left of the screen
   put item 1 of tScreen + 10, item 2 of tScreen + 10, item 1 of tScreen + 410, item 2 of tScreen + 40 into tRect
   set the palette_rect_revMenubar of stack "revPreferences" to tRect
   set the loc of stack kStack to item 1 of tScreen + 50, item 2 of tScreen + 50
   set the statusMessage of stack kStack to "Loading..."
   TestAssert "the status is shown", field "status" of stack kStack is "Loading..."
   TestAssert "in the middle of the menu bar's screen", \
         the loc of stack kStack is (item 1 of tScreen + item 3 of tScreen) div 2 & comma & \
         (item 2 of tScreen + item 4 of tScreen) div 2
end TestMovesToTheMenubarsScreen

on TestOnlyOnTheFirstStatus
   local tScreen
   put line 1 of the screenRects into tScreen
   set the palette_rect_revMenubar of stack "revPreferences" to \
         item 1 of tScreen + 10, item 2 of tScreen + 10, item 1 of tScreen + 410, item 2 of tScreen + 40
   set the statusMessage of stack kStack to "one"
   set the loc of stack kStack to item 1 of tScreen + 60, item 2 of tScreen + 60
   set the statusMessage of stack kStack to "two"
   TestAssert "a later status leaves it where it is", \
         the loc of stack kStack is (item 1 of tScreen + 60) & comma & (item 2 of tScreen + 60)
end TestOnlyOnTheFirstStatus

on TestNoSavedPlaceStays
   local tLoc
   put the loc of stack kStack into tLoc
   set the statusMessage of stack kStack to "Loading..."
   TestAssert "no saved place: it stays", the loc of stack kStack is tLoc
end TestNoSavedPlaceStays

on TestOffEveryScreenStays
   local tLoc
   -- as a rect saved while the menu bar was minimised is
   set the palette_rect_revMenubar of stack "revPreferences" to "-32000,-32000,-31600,-31970"
   put the loc of stack kStack into tLoc
   set the statusMessage of stack kStack to "Loading..."
   TestAssert "a place on no screen: it stays", the loc of stack kStack is tLoc
end TestOffEveryScreenStays

on TestNotARectStays
   local tLoc
   set the palette_rect_revMenubar of stack "revPreferences" to "left,top"
   put the loc of stack kStack into tLoc
   set the statusMessage of stack kStack to "Loading..."
   TestAssert "a place that is no rect: it stays", the loc of stack kStack is tLoc
end TestNotARectStays

-- A stack with the splash's behaviour and status field, which has had no
-- status yet (the behaviour keeps whether it has placed the splash, so each
-- test starts from a fresh copy of the behaviour)
private command __NewSplash
   local tScript
   if there is a stack kStack then delete stack kStack
   put the script of stack kBehavior into tScript
   delete stack kBehavior
   create invisible stack kBehavior
   set the script of stack kBehavior to tScript
   create invisible stack kStack
   set the defaultStack to kStack
   create field "status"
   set the behavior of stack kStack to the long id of stack kBehavior
end __NewSplash
