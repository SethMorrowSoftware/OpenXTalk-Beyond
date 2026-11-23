script "TestProjectBrowserStrayClip"
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

-- The Project Browser's own stack
-- (ide/Toolset/palettes/project browser/revideprojectbrowser.livecode)
-- carried an audio clip, "Clap.mp3" (10,577 bytes of sound), from
-- LiveCode's IDE, where it is still in livecode-ide's develop branch. No
-- script plays or names it, and it was listed with the stack's objects
-- whenever the Project Browser listed its own stack (HyperXTalk's issue
-- 612 asked why). It is taken out, and the stack keeps everything else.
--
-- The stack file is only loaded, never opened, so none of its handlers
-- run; a stack of that name already in memory (the IDE's own Project
-- Browser) is left as it is, and the test reads the file by its path.

constant kStackName = "revIDEProjectBrowser"

local sFound

private function stackPath
   return TestGetIDERepositoryPath() & "/Toolset/palettes/project browser/revideprojectbrowser.livecode"
end stackPath

on TestSetup
   put there is a stack kStackName into sFound
   if sFound then
      -- the IDE's Project Browser is in memory: its stack is the one
      -- in the file only when it was loaded from this repository
      if the effective filename of stack kStackName is not stackPath() then
         throw "SKIP another Project Browser stack is in memory"
      end if
   end if
end TestSetup

on TestTeardown
   if not sFound and there is a stack kStackName then
      delete stack kStackName
   end if
end TestTeardown

on TestProjectBrowserHasNoAudioClips
   local tStack
   put the long id of stack stackPath() into tStack
   TestAssert "the stack file loads", tStack is not empty
   TestAssert "it is the Project Browser", the short name of tStack is kStackName
   TestAssert "no audio clip, Clap.mp3 or another", the number of audioclips of tStack is 0
   TestAssert "no video clip", the number of videoclips of tStack is 0
end TestProjectBrowserHasNoAudioClips

on TestProjectBrowserKeepsItsCards
   local tStack
   put the long id of stack stackPath() into tStack
   -- what the window is made of is still there
   TestAssert "card list", there is a card "list" of tStack
   TestAssert "card templates", there is a card "templates" of tStack
   TestAssert "the object list", there is a group "objectList" of card "list" of tStack
   TestAssert "its scrollbar", there is a scrollbar "dvVScrollbar" of card "list" of tStack
   TestAssert "the audio clip row's icon", there is an image "audioclip.png" of card "templates" of tStack
end TestProjectBrowserKeepsItsCards
