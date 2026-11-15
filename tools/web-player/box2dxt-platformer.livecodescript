script "Box2DxtPlatformerBuilder"
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

-- Builds stacks/Box2Dxt Platformer.oxtstack: the xTalk Suite's Box2Dxt
-- platformer (seven scrolling levels on Box2D, with the b2k Game Kit
-- carried in its script), with everything it draws and plays already
-- inside it, so that it opens in the Stack Player straight to its title.
--
-- The game is the suite's, as box2dxt-platformer/pin.json pins it, and is
-- not changed here: its script becomes the stack's script as it is. Its
-- own first run asks for the Spritesheets folder and imports every atlas,
-- frame and sound into the stack, then asks to save it (pfImportMedia);
-- this does that import without the questions: the folder is given, and
-- the stack is saved here. The stack is never edited by hand. Fetch the
-- pinned files, then build it with any OXT-Beyond engine:
--
--    python3 tools/web-player/box2dxt_platformer_files.py --out <dir>
--    OXT_PLATFORMER_FILES=<dir> <engine> -ui tools/web-player/box2dxt-platformer.livecodescript
--
-- OXT_PLATFORMER names another file to write. It prints "BUILT <file>"
-- or "FAILED <why>".
--
-- What goes in, all made by the game's own handlers:
--   the chrome    buildPfUI: the title, the HUD, the level picker, the
--                 card and pause overlays (the stack's uPfUIVersionTag, so
--                 the game's openCard does not build them again)
--   the art       pfLoadSheets: each atlas's image, its regions stamped on
--                 it; pfImportWarm: every frame the seven levels draw,
--                 sliced at its play scale and mirrored where it turns
--   the sounds    pfMakeSounds: every cue, synthesized
--   the stamp     uPfMediaV, the game's kPfMediaV: the import is whole, so
--                 the game adopts it (pfMedia) and never asks for a folder
-- The atlases' folder is remembered as uSpriteSheetFolderPath, which is
-- then only the Kit's name for the images in the stack (pfArtFolder): it
-- is "Spritesheets", relative to the folder given, wherever that was.

constant kName = "Box2Dxt Platformer"

on startup
   local tFile, tFiles, tError
   put $OXT_PLATFORMER into tFile
   if tFile is empty then
      put the effective filename of me into tFile
      set the itemDelimiter to slash
      put "stacks/" & kName & ".oxtstack" into the last item of tFile
      set the itemDelimiter to comma
   end if
   put $OXT_PLATFORMER_FILES into tFiles
   try
      if tFiles is empty then
         throw "OXT_PLATFORMER_FILES names no folder (box2dxt_platformer_files.py --out makes one)"
      end if
      buildStack tFiles, tFile
   catch tError
      write "FAILED" && tError & return to stdout
      quit 1
   end try
   write "BUILT" && tFile & return to stdout
   quit 0
end startup

private command buildStack pFiles, pFile
   local tScript, tSheets, tStack, tVersion, tOk
   put textDecode(url ("binfile:" & pFiles & "/box2dxt-platformer.livecodescript"), "UTF-8") into tScript
   if tScript is empty then
      throw "no box2dxt-platformer.livecodescript in" && pFiles
   end if
   -- the folder by a relative path, so that the stack names it the same
   -- wherever it was built (the Kit keys the images it keeps by it)
   set the defaultFolder to pFiles
   put "Spritesheets" into tSheets
   if there is no file (tSheets & "/spritesheet-characters-default.png") then
      throw "no Spritesheets/spritesheet-characters-default.png in" && pFiles
   end if
   put constantOf(tScript, "kPfMediaV") into tVersion

   if there is a stack kName then
      delete stack kName
   end if
   create invisible stack kName
   put the long id of stack kName into tStack
   set the defaultStack to kName
   set the rect of tStack to 0, 0, 1024, 640
   set the script of tStack to tScript
   if the result is not empty then
      throw "the platformer's script does not compile:" && the result
   end if
   set the uSpriteSheetFolderPath of tStack to tSheets

   -- as the game's own first run does (openCard, pfImportMedia), with
   -- messages locked as it locks them, and no question asked
   dispatch "b2kSheetPersist" to tStack with true
   dispatch "buildPfUI" to tStack
   lock messages
   dispatch function "pfLoadSheets" to tStack
   put the result into tOk
   if tOk is not true then
      unlock messages
      throw "the atlases did not load:" && tOk
   end if
   dispatch "pfMakeSounds" to tStack
   dispatch "pfImportWarm" to tStack
   unlock messages
   set the uPfMediaV of tStack to tVersion
   dispatch function "pfMedia" to tStack
   if the result is not true then
      throw "the game does not take the import as whole (pfMedia)"
   end if
   save tStack as pFile
   if the result is not empty then
      throw "saving" && pFile & ":" && the result
   end if
   delete stack kName
end buildStack

-- The value of a constant of a script: constant kX = "v"
private function constantOf pScript, pName
   local tLine
   repeat for each line tLine in pScript
      if word 1 of tLine is "constant" and word 2 of tLine is pName and word 3 of tLine is "=" then
         get word 4 of tLine
         replace quote with empty in it
         return it
      end if
   end repeat
   throw "the platformer's script has no constant" && pName
end constantOf
