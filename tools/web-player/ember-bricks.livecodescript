script "EmberBricksBuilder"
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

-- Builds stacks/Ember Bricks.oxtstack, a brick-breaking game for a phone,
-- a browser and a desktop, with an online duel for two. The stack is
-- never edited by hand: change this script, the game's script
-- (ember-bricks-stack.livecodescript beside it) or its levels
-- (ember-bricks/levels.txt), and build it again, with any OXT-Beyond
-- engine (the IDE's, or the development engine of a build):
--
--    <engine> -ui tools/web-player/ember-bricks.livecodescript
--
-- OXT_EMBER_BRICKS names another file to write. It prints "BUILT <file>"
-- or "FAILED <why>".
--
-- What goes in:
--   card "Game"   everything the game shows: the arena, a fixed set of
--                 graphics for each kind of thing in it (bricks, balls,
--                 falling sparks, bolts, bits of a broken brick: made
--                 once, shown and hidden, never created while it plays),
--                 the rival's arena for a duel, the HUD, the banner, and
--                 the screens (Title, Howto, Settings, Levels, Paused,
--                 Clear, Over, Lobby, Result), each a group over the arena
--   the levels    ember-bricks/levels.txt, as the custom property cLevels
--   the sounds    ember-bricks/sounds (made by make_assets.py there), as
--                 the custom property set cSounds
--   the font      Atkinson Hyperlegible, as the custom properties
--                 cFontRegular and cFontBold, which the game hands to
--                 "start using font file" as it opens
--   the settings  for Save as Standalone: an Android package, with
--                 OXT-Beyond's own engine, edge to edge
--
-- There are no pictures: every thing the game shows is a graphic or a
-- field, so it is as sharp on a phone's screen as in a window three times
-- as wide. Every place and size of a control, and the size of its words,
-- is set by the game's ebLayout as it opens and whenever the window
-- changes: here they are only made, with their look. A control with words
-- keeps the size of them for a window 390 points wide in its cSize. The
-- stack's script is set last, so that nothing it does runs while the
-- stack is built.

-- The window the stack opens with, where it has a window: on a desktop,
-- and on a desktop's page in the Stack Player, which shows a stack at its
-- own size. Wide, so that the game opens there with its HUD at the
-- arena's sides, and no taller than a laptop's page. A phone gives the
-- game its whole screen, whatever this says
constant kWidth = 900
constant kHeight = 640
constant kStack = "Ember Bricks"
constant kIdentifier = "io.github.sethmorrowsoftware.emberbricks"

-- How many of each thing there are (the game counts them as it opens).
-- The bricks are a grid of 10 by 14; the rival's are the same grid, small
constant kBricks = 140
constant kBalls = 8
constant kDrops = 6
constant kBolts = 8
constant kSparks = 40
constant kPops = 6
constant kMotes = 16
constant kLives = 5
constant kChips = 6
constant kRivalBalls = 3

-- The look (the game's script has the same colours)
constant kFont = "Atkinson Hyperlegible"
constant kBack = "#140E0C"
constant kArena = "#1E1512"
constant kWall = "#6B4631"
constant kAmber = "#FFB52E"
constant kAmberDown = "#D18A12"
constant kEmber = "#FF7A3D"
constant kInk = "#FFF6EC"
constant kDark = "#2A1606"
constant kMuted = "#C7B3A1"
constant kGood = "#7CF29A"
constant kBad = "#FF5D73"
constant kCool = "#5CD6FF"
constant kPanel = "#2A1D18"
constant kPanelDown = "#49332B"
constant kEdge = "#8A5A3C"

on startup
   local tFile, tError
   put $OXT_EMBER_BRICKS into tFile
   if tFile is empty then
      put the effective filename of me into tFile
      set the itemDelimiter to slash
      put "stacks/Ember Bricks.oxtstack" into the last item of tFile
      set the itemDelimiter to comma
   end if
   try
      buildStack tFile
   catch tError
      write "FAILED" && tError & return to stdout
      quit 1
   end try
   write "BUILT" && tFile & return to stdout
   quit 0
end startup

private command buildStack pFile
   local tScript, tLevels
   if there is a stack kStack then
      delete stack kStack
   end if
   create invisible stack kStack
   set the defaultStack to kStack
   set the rect of stack kStack to 100, 60, 100 + kWidth, 60 + kHeight
   set the cWindow of stack kStack to kWidth & comma & kHeight
   -- (a small phone on its side is 320 high)
   set the minWidth of stack kStack to 320
   set the minHeight of stack kStack to 320
   set the resizable of stack kStack to true
   set the backgroundColor of stack kStack to kBack
   set the textFont of stack kStack to empty
   set the textSize of stack kStack to 14
   -- the page calls ebPageHidden when it is hidden (another app, a locked
   -- phone), so that a ball never flies on behind it, and ebPasted with
   -- what its clipboard held (the duel's invite); ebState says how the
   -- game is and ebRectOf where a control is, for the checks that play
   -- it in a browser as anyone would, with taps
   set the cJavascriptHandlers of stack kStack to "ebPageHidden" & return & "ebPasted" & return & "ebState" & return & "ebRectOf"

   put fileText(assetPath("levels.txt")) into tLevels
   set the cLevels of stack kStack to tLevels
   importSounds
   importFonts

   set the name of card 1 of stack kStack to "Game"
   set the backgroundColor of card "Game" to kBack
   buildPlay
   buildRival
   buildHud
   buildBanner
   buildShade
   buildTitle
   buildHowto
   buildSettings
   buildLevels levelCount(tLevels)
   buildPaused
   buildClear
   buildOver
   buildLobby
   buildResult
   standaloneSettings

   -- last: the script, which lays everything out as the stack opens
   put stackScript() into tScript
   set the script of stack kStack to tScript
   if the result is not empty then
      throw "the stack's script does not compile:" && the result
   end if
   set the visible of stack kStack to true
   save stack kStack as pFile
   if the result is not empty then
      throw "cannot save" && pFile & ":" && the result
   end if
end buildStack

-- A file beside this script, in ember-bricks/
private function assetPath pName
   local tFile
   put the effective filename of me into tFile
   set the itemDelimiter to slash
   put "ember-bricks/" & pName into the last item of tFile
   return tFile
end assetPath

private function fileText pFile
   local tText
   open file pFile for "UTF-8" text read
   if the result is not empty then
      throw "cannot read" && pFile & ":" && the result
   end if
   read from file pFile until end
   put it into tText
   close file pFile
   return tText
end fileText

private function fileData pFile
   local tData
   if there is not a file pFile then
      throw "no file" && pFile
   end if
   put url ("binfile:" & pFile) into tData
   if tData is empty then
      throw "cannot read" && pFile
   end if
   return tData
end fileData

-- How many levels levels.txt has: a line "= Name" begins each
private function levelCount pLevels
   local tLine, tCount
   put 0 into tCount
   repeat for each line tLine in pLevels
      if char 1 to 2 of tLine is "= " then
         add 1 to tCount
      end if
   end repeat
   if tCount < 1 then
      throw "levels.txt has no level"
   end if
   return tCount
end levelCount

private command importSounds
   local tFolder, tFile, tFiles
   put assetPath("sounds") into tFolder
   set the defaultFolder to tFolder
   put the files into tFiles
   repeat for each line tFile in tFiles
      if tFile ends with ".wav" then
         set the cSounds[char 1 to -5 of tFile] of stack kStack to fileData(tFolder & "/" & tFile)
      end if
   end repeat
   if the number of lines of the customKeys["cSounds"] of stack kStack < 27 then
      throw "the sounds are not all there:" && the customKeys["cSounds"] of stack kStack
   end if
end importSounds

private command importFonts
   set the cFontRegular of stack kStack to fileData(assetPath("fonts/AtkinsonHyperlegible-Regular.ttf"))
   set the cFontBold of stack kStack to fileData(assetPath("fonts/AtkinsonHyperlegible-Bold.ttf"))
end importFonts

----------------------------------------------------------------------
-- The arena, back to front: the embers that drift behind the screens,
-- the arena and its walls, the bricks, the net, the bolts, the falling
-- sparks, the bits of a broken brick, the paddle and its cannons, the
-- balls, then the hint, the floating words and the flash of a lost ball

private command buildPlay
   local i, tName
   repeat with i = 1 to kMotes
      put "Mote" && i into tName
      create graphic tName
      setOval the long id of graphic tName, kEmber
      if i mod 3 is 0 then
         set the backgroundColor of graphic tName to kAmber
      end if
      set the blendLevel of graphic tName to 35
      set the visible of graphic tName to false
   end repeat
   create graphic "Arena"
   setBox the long id of graphic "Arena", kArena
   create graphic "Walls"
   set the style of graphic "Walls" to "polygon"
   set the opaque of graphic "Walls" to false
   set the filled of graphic "Walls" to false
   set the lineSize of graphic "Walls" to 2
   set the foregroundColor of graphic "Walls" to kWall
   repeat with i = 1 to kBricks
      makeBrick "Brick" && i
   end repeat
   create graphic "Net"
   setBox the long id of graphic "Net", kCool
   set the visible of graphic "Net" to false
   repeat with i = 1 to kBolts
      put "Bolt" && i into tName
      create graphic tName
      setBox the long id of graphic tName, "#FFE08A"
      set the visible of graphic tName to false
   end repeat
   repeat with i = 1 to kDrops
      put "Drop" && i into tName
      create graphic tName
      setOval the long id of graphic tName, kAmber
      set the lineSize of graphic tName to 2
      set the foregroundColor of graphic tName to kDark
      set the showName of graphic tName to true
      set the label of graphic tName to "W"
      set the textFont of graphic tName to kFont
      set the textStyle of graphic tName to "bold"
      set the textSize of graphic tName to 12
      set the visible of graphic tName to false
   end repeat
   repeat with i = 1 to kSparks
      put "Spark" && i into tName
      create graphic tName
      setBox the long id of graphic tName, kAmber
      set the visible of graphic tName to false
   end repeat
   repeat for each item tName in "Cannon 1,Cannon 2"
      create graphic tName
      setBox the long id of graphic tName, "#FFE08A"
      set the visible of graphic tName to false
   end repeat
   create graphic "Paddle"
   set the style of graphic "Paddle" to "roundrect"
   set the opaque of graphic "Paddle" to true
   set the filled of graphic "Paddle" to true
   set the lineSize of graphic "Paddle" to 0
   set the antialiased of graphic "Paddle" to true
   set the backgroundColor of graphic "Paddle" to kAmber
   set the visible of graphic "Paddle" to false
   repeat with i = 1 to kBalls
      put "Ball" && i into tName
      create graphic tName
      setOval the long id of graphic tName, "#FFF3D6"
      set the visible of graphic tName to false
   end repeat
   create field "Hint"
   setLabel the long id of field "Hint", empty, 15, kMuted, "bold", "center"
   set the visible of field "Hint" to false
   repeat with i = 1 to kPops
      create field ("Pop" && i)
      setLabel the long id of field ("Pop" && i), empty, 15, kInk, "bold", "center"
      set the visible of field ("Pop" && i) to false
   end repeat
   create graphic "Flash"
   setBox the long id of graphic "Flash", kBad
   set the blendLevel of graphic "Flash" to 75
   set the visible of graphic "Flash" to false
end buildPlay

-- A brick: a rectangle with its corners rounded. The game gives it its
-- colours (a gradient, light over dark) and, for a bomb or an ember, a
-- mark, its label
private command makeBrick pName, pGroup
   if pGroup is empty then
      create graphic pName
   else
      create graphic pName in group pGroup
   end if
   set the style of graphic pName to "roundrect"
   set the opaque of graphic pName to true
   set the filled of graphic pName to true
   set the lineSize of graphic pName to 0
   set the antialiased of graphic pName to true
   set the roundRadius of graphic pName to 4
   set the backgroundColor of graphic pName to kEmber
   set the showName of graphic pName to false
   set the textFont of graphic pName to kFont
   set the textStyle of graphic pName to "bold"
   set the textSize of graphic pName to 11
   set the visible of graphic pName to false
end makeBrick

-- The rival's arena in a duel: the same grid of bricks, small and flat,
-- a paddle and a few balls, and over them a name and a score
private command buildRival
   local i, tName
   create group "Rival"
   create graphic "Rival Arena" in group "Rival"
   setBox the long id of graphic "Rival Arena", kArena
   set the lineSize of graphic "Rival Arena" to 1
   set the foregroundColor of graphic "Rival Arena" to kWall
   repeat with i = 1 to kBricks
      put "Rival Brick" && i into tName
      create graphic tName in group "Rival"
      setBox the long id of graphic tName, kEmber
      set the visible of graphic tName to false
   end repeat
   create graphic "Rival Paddle" in group "Rival"
   setBox the long id of graphic "Rival Paddle", kCool
   repeat with i = 1 to kRivalBalls
      put "Rival Ball" && i into tName
      create graphic tName in group "Rival"
      setOval the long id of graphic tName, "#FFF3D6"
      set the visible of graphic tName to false
   end repeat
   create field "Rival Name" in group "Rival"
   setLabel the long id of field "Rival Name", "RIVAL", 11, kCool, "bold", "left"
   create field "Rival Score" in group "Rival"
   setLabel the long id of field "Rival Score", "0", 13, kInk, "bold", "right"
   set the visible of group "Rival" to false
end buildRival

-- The score, the level, the heat, the lives, the pause button, and a chip
-- for each spark that is working (its name over the time it has left)
private command buildHud
   local i, tName
   create group "HUD"
   create field "Score Label" in group "HUD"
   setLabel the long id of field "Score Label", "SCORE", 11, kMuted, "bold", "left"
   create field "Score" in group "HUD"
   setLabel the long id of field "Score", "0", 24, kInk, "bold", "left"
   create field "Best" in group "HUD"
   setLabel the long id of field "Best", "BEST 0", 12, kMuted, "bold", "left"
   create field "Stage" in group "HUD"
   setLabel the long id of field "Stage", "LEVEL 1", 12, kAmber, "bold", "left"
   create field "Stage Name" in group "HUD"
   setLabel the long id of field "Stage Name", empty, 12, kMuted, "plain", "left"
   create field "Clock" in group "HUD"
   setLabel the long id of field "Clock", empty, 20, kInk, "bold", "center"
   create field "Heat Text" in group "HUD"
   setLabel the long id of field "Heat Text", "HEAT x1", 12, kMuted, "bold", "center"
   create graphic "Heat Back" in group "HUD"
   setBox the long id of graphic "Heat Back", "#3A2A22"
   create graphic "Heat Fill" in group "HUD"
   setBox the long id of graphic "Heat Fill", kEmber
   repeat with i = 1 to kLives
      put "Life" && i into tName
      create graphic tName in group "HUD"
      setOval the long id of graphic tName, "#FFF3D6"
   end repeat
   -- the pause button: its two bars between its shape and its face
   makeShape "Pause", "HUD", false
   create graphic "Pause Bar 1" in group "HUD"
   setBox the long id of graphic "Pause Bar 1", kInk
   create graphic "Pause Bar 2" in group "HUD"
   setBox the long id of graphic "Pause Bar 2", kInk
   makeFace "Pause", empty, "HUD", false
   set the showName of button "Pause" to false
   repeat with i = 1 to kChips
      put "Chip" && i into tName
      create graphic (tName && "Back") in group "HUD"
      set the style of graphic (tName && "Back") to "roundrect"
      set the opaque of graphic (tName && "Back") to true
      set the filled of graphic (tName && "Back") to true
      set the lineSize of graphic (tName && "Back") to 0
      set the roundRadius of graphic (tName && "Back") to 6
      set the backgroundColor of graphic (tName && "Back") to kPanel
      create graphic (tName && "Fill") in group "HUD"
      setBox the long id of graphic (tName && "Fill"), kAmber
      create field (tName && "Text") in group "HUD"
      setLabel the long id of field (tName && "Text"), empty, 10, kInk, "bold", "center"
      set the visible of graphic (tName && "Back") to false
      set the visible of graphic (tName && "Fill") to false
      set the visible of field (tName && "Text") to false
   end repeat
   set the visible of group "HUD" to false
end buildHud

-- A level's name, a spark's, and what a level clear was worth
private command buildBanner
   create group "Banner"
   create graphic "Banner Back" in group "Banner"
   setBox the long id of graphic "Banner Back", "#0B0706"
   set the blendLevel of graphic "Banner Back" to 30
   create field "Banner Text" in group "Banner"
   setLabel the long id of field "Banner Text", empty, 26, kInk, "bold", "center"
   create field "Banner Sub" in group "Banner"
   setLabel the long id of field "Banner Sub", empty, 14, kAmber, "bold", "center"
   set the visible of group "Banner" to false
end buildBanner

-- The dark veil over the arena, behind a panel
private command buildShade
   create graphic "Shade"
   setBox the long id of graphic "Shade", "#070403"
   set the blendLevel of graphic "Shade" to 30
   set the visible of graphic "Shade" to false
end buildShade

private command buildTitle
   create group "Title"
   create field "Logo Ember" in group "Title"
   setLabel the long id of field "Logo Ember", "EMBER", 58, kAmber, "bold", "center"
   create field "Logo Bricks" in group "Title"
   setLabel the long id of field "Logo Bricks", "B R I C K S", 26, kInk, "bold", "center"
   create graphic "Logo Line" in group "Title"
   setBox the long id of graphic "Logo Line", kEmber
   create field "Tagline" in group "Title"
   setText the long id of field "Tagline", "Break the bricks. Keep the heat. Catch the sparks.", 15, kMuted, "center"
   makeButton "Play", "PLAY", "Title", true
   makeButton "Levels Open", "LEVELS", "Title", false
   makeButton "Duel Open", "ONLINE DUEL", "Title", false
   makeButton "Howto Open", "HOW TO PLAY", "Title", false
   makeButton "Settings Open", "SETTINGS", "Title", false
   create field "Records" in group "Title"
   setLabel the long id of field "Records", "BEST 0", 13, kMuted, "bold", "center"
   set the visible of group "Title" to false
end buildTitle

private command buildHowto
   local i, tTitles, tTexts, tName
   create group "Howto"
   makePanel "Howto"
   create field "Howto Title" in group "Howto"
   setLabel the long id of field "Howto Title", "HOW TO PLAY", 20, kAmber, "bold", "center"
   put "MOVE THE PADDLE,BUILD THE HEAT,CATCH THE SPARKS,MIND THE DARK ONES" into tTitles
   put "Slide a finger anywhere, or move the mouse, or use the arrow keys. Let go, click or press Space to send the ball off." & return & \
         "Every brick you break heats the ball. Keep breaking them and each is worth up to five times as much; wait too long, or lose the ball, and it cools." & return & \
         "Bright sparks fall from some bricks: a wider paddle, more balls, a fireball, a slower ball, a paddle that grips, bolts, a net, a life." & return & \
         "A dark spark with a red ring shrinks the paddle or speeds the ball. Let it fall." into tTexts
   repeat with i = 1 to 4
      put "Howto Icon" && i into tName
      create graphic tName in group "Howto"
      create field ("Howto Head" && i) in group "Howto"
      setLabel the long id of field ("Howto Head" && i), item i of tTitles, 13, kInk, "bold", "left"
      create field ("Howto Text" && i) in group "Howto"
      setText the long id of field ("Howto Text" && i), line i of tTexts, 14, kMuted, "left"
   end repeat
   -- a paddle, a brick, a spark and a dark one
   set the style of graphic "Howto Icon 1" to "roundrect"
   set the opaque of graphic "Howto Icon 1" to true
   set the lineSize of graphic "Howto Icon 1" to 0
   set the roundRadius of graphic "Howto Icon 1" to 8
   set the backgroundColor of graphic "Howto Icon 1" to kAmber
   set the style of graphic "Howto Icon 2" to "roundrect"
   set the opaque of graphic "Howto Icon 2" to true
   set the lineSize of graphic "Howto Icon 2" to 0
   set the roundRadius of graphic "Howto Icon 2" to 4
   set the backgroundColor of graphic "Howto Icon 2" to "#FF5D5D"
   setOval the long id of graphic "Howto Icon 3", kGood
   setOval the long id of graphic "Howto Icon 4", "#3A1016"
   repeat with i = 3 to 4
      put "Howto Icon" && i into tName
      set the lineSize of graphic tName to 2
      set the showName of graphic tName to true
      set the textFont of graphic tName to kFont
      set the textStyle of graphic tName to "bold"
      set the textSize of graphic tName to 13
      set the cSize of graphic tName to 13
   end repeat
   set the foregroundColor of graphic "Howto Icon 3" to kDark
   set the label of graphic "Howto Icon 3" to "W"
   set the foregroundColor of graphic "Howto Icon 4" to kBad
   set the label of graphic "Howto Icon 4" to "><"
   makeButton "Howto Go", "GOT IT", "Howto", true
   set the visible of group "Howto" to false
end buildHowto

private command buildSettings
   create group "Settings"
   makePanel "Settings"
   create field "Settings Title" in group "Settings"
   setLabel the long id of field "Settings Title", "SETTINGS", 22, kInk, "bold", "center"
   makeButton "Sound", "SOUND: ON", "Settings", false
   makeButton "Buzz", "BUZZ: ON", "Settings", false
   makeButton "Effects", "EFFECTS: FULL", "Settings", false
   makeButton "Full", "FULL SCREEN", "Settings", false
   create field "Settings Note" in group "Settings"
   setText the long id of field "Settings Note", empty, 13, kAmber, "center"
   create field "Credits" in group "Settings"
   setText the long id of field "Credits", "Every sound was made for this game. Font: Atkinson Hyperlegible, by the Braille Institute (SIL Open Font License). Made with OXT-Beyond.", 12, kMuted, "center"
   makeButton "Settings Back", "DONE", "Settings", true
   set the visible of group "Settings" to false
end buildSettings

-- A button for each level; the game dims those not yet reached
private command buildLevels pCount
   local i
   create group "Levels"
   makePanel "Levels"
   create field "Levels Title" in group "Levels"
   setLabel the long id of field "Levels Title", "LEVELS", 22, kInk, "bold", "center"
   repeat with i = 1 to pCount
      makeButton "Level" && i, i, "Levels", false
   end repeat
   create field "Levels Note" in group "Levels"
   setText the long id of field "Levels Note", "Clear a level to open the next.", 13, kMuted, "center"
   makeButton "Levels Back", "BACK", "Levels", true
   set the visible of group "Levels" to false
end buildLevels

private command buildPaused
   create group "Paused"
   makePanel "Paused"
   create field "Paused Title" in group "Paused"
   setLabel the long id of field "Paused Title", "PAUSED", 24, kInk, "bold", "center"
   makeButton "Resume", "RESUME", "Paused", true
   makeButton "Restart", "RESTART", "Paused", false
   makeButton "Pause Settings", "SETTINGS", "Paused", false
   makeButton "Pause Home", "HOME", "Paused", false
   set the visible of group "Paused" to false
end buildPaused

private command buildClear
   create group "Clear"
   makePanel "Clear"
   create field "Clear Title" in group "Clear"
   setLabel the long id of field "Clear Title", "LEVEL CLEAR", 24, kGood, "bold", "center"
   create field "Clear Name" in group "Clear"
   setLabel the long id of field "Clear Name", empty, 14, kMuted, "bold", "center"
   create field "Clear Lines" in group "Clear"
   setLabel the long id of field "Clear Lines", empty, 14, kInk, "plain", "left"
   create field "Clear Values" in group "Clear"
   setLabel the long id of field "Clear Values", empty, 14, kAmber, "bold", "right"
   create field "Clear Total" in group "Clear"
   setLabel the long id of field "Clear Total", "0", 34, kAmber, "bold", "center"
   makeButton "Next", "NEXT LEVEL", "Clear", true
   set the visible of group "Clear" to false
end buildClear

private command buildOver
   create group "Over"
   makePanel "Over"
   create field "Over Title" in group "Over"
   setLabel the long id of field "Over Title", "OUT OF LIVES", 22, kBad, "bold", "center"
   create field "Final" in group "Over"
   setLabel the long id of field "Final", "0", 40, kAmber, "bold", "center"
   create field "Best Note" in group "Over"
   setLabel the long id of field "Best Note", empty, 14, kGood, "bold", "center"
   create field "Stats" in group "Over"
   setLabel the long id of field "Stats", empty, 13, kMuted, "plain", "center"
   makeButton "Again", "PLAY AGAIN", "Over", true
   makeButton "Over Home", "HOME", "Over", false
   set the visible of group "Over" to false
end buildOver

-- The duel's lobby: host or join, the invite to send and the answer to
-- take, each a field with a button to copy it or paste into it
private command buildLobby
   create group "Lobby"
   makePanel "Lobby"
   create field "Lobby Title" in group "Lobby"
   setLabel the long id of field "Lobby Title", "ONLINE DUEL", 22, kInk, "bold", "center"
   create field "Lobby Text" in group "Lobby"
   setText the long id of field "Lobby Text", empty, 14, kMuted, "center"
   makeButton "Host", "HOST A DUEL", "Lobby", true
   makeButton "Join", "JOIN A DUEL", "Lobby", false
   create field "Lobby Step" in group "Lobby"
   setLabel the long id of field "Lobby Step", empty, 13, kAmber, "bold", "left"
   create graphic "Code Back" in group "Lobby"
   set the style of graphic "Code Back" to "roundrect"
   set the opaque of graphic "Code Back" to true
   set the filled of graphic "Code Back" to true
   set the roundRadius of graphic "Code Back" to 8
   set the lineSize of graphic "Code Back" to 1
   set the foregroundColor of graphic "Code Back" to kEdge
   set the backgroundColor of graphic "Code Back" to "#120C0A"
   create field "Code" in group "Lobby"
   set the lockText of field "Code" to false
   set the traversalOn of field "Code" to true
   set the opaque of field "Code" to false
   set the showBorder of field "Code" to false
   set the threeD of field "Code" to false
   set the dontWrap of field "Code" to false
   set the autoTab of field "Code" to false
   set the margins of field "Code" to 6
   set the textFont of field "Code" to kFont
   set the textSize of field "Code" to 11
   set the cSize of field "Code" to 11
   set the textColor of field "Code" to kInk
   set the showFocusBorder of field "Code" to false
   makeButton "Code Copy", "COPY THE INVITE", "Lobby", true
   makeButton "Code Paste", "PASTE", "Lobby", true
   makeButton "Code Go", "CONNECT", "Lobby", false
   create field "Lobby Note" in group "Lobby"
   setText the long id of field "Lobby Note", empty, 13, kAmber, "center"
   makeButton "Lobby Back", "BACK", "Lobby", false
   set the visible of group "Lobby" to false
end buildLobby

private command buildResult
   create group "Result"
   makePanel "Result"
   create field "Result Title" in group "Result"
   setLabel the long id of field "Result Title", "YOU WIN", 26, kGood, "bold", "center"
   create field "Result You" in group "Result"
   setLabel the long id of field "Result You", "YOU  0", 20, kAmber, "bold", "center"
   create field "Result Them" in group "Result"
   setLabel the long id of field "Result Them", "RIVAL  0", 20, kCool, "bold", "center"
   create field "Result Note" in group "Result"
   setText the long id of field "Result Note", empty, 13, kMuted, "center"
   makeButton "Rematch", "REMATCH", "Result", true
   makeButton "Result Home", "LEAVE", "Result", false
   set the visible of group "Result" to false
end buildResult

-- What Save as Standalone builds from this stack: an Android package with
-- OXT-Beyond's own engine, edge to edge, for arm64, signed for
-- development. The other platforms are as the IDE has them until they
-- are chosen there.
private command standaloneSettings
   local tS, tPermission
   put kStack into tS["name"]
   put "search" into tS["inclusions"]
   put true into tS["android"]
   put true into tS["android,arm64"]
   put false into tS["android,armv7"]
   put "beyond" into tS["android,engine"]
   put true into tS["android,edge to edge"]
   put kIdentifier into tS["android,identifier"]
   put kStack into tS["android,label"]
   put "1.0.0" into tS["android,version name"]
   put 1 into tS["android,version code"]
   put "sign for development only" into tS["android,signing"]
   put "portrait" into tS["android,initial orientation"]
   repeat for each item tPermission in "INTERNET,VIBRATE"
      put true into tS["android,application permissions"][tPermission]
   end repeat
   set the customProperties["cRevStandaloneSettings"] of stack kStack to tS
end standaloneSettings

----------------------------------------------------------------------
-- The parts the screens are made of

-- A panel's glass, and the ember bar over its title (the game places
-- them for the panel's size)
private command makePanel pGroup
   create graphic (pGroup && "Glass") in group pGroup
   set the style of graphic (pGroup && "Glass") to "roundrect"
   set the opaque of graphic (pGroup && "Glass") to true
   set the filled of graphic (pGroup && "Glass") to true
   set the roundRadius of graphic (pGroup && "Glass") to 18
   set the backgroundColor of graphic (pGroup && "Glass") to kPanel
   set the lineSize of graphic (pGroup && "Glass") to 2
   set the foregroundColor of graphic (pGroup && "Glass") to kEdge
   set the antialiased of graphic (pGroup && "Glass") to true
   create graphic (pGroup && "Trim") in group pGroup
   setBox the long id of graphic (pGroup && "Trim"), kEmber
end makePanel

-- A button of the screens: its shape, a rectangle with round corners
-- (amber for the main one), and over it a button with no look of its
-- own, its label, which takes the taps. The shape's cUp and cDown are
-- its colours, up and pressed.
private command makeButton pName, pLabel, pGroup, pMain
   makeShape pName, pGroup, pMain
   makeFace pName, pLabel, pGroup, pMain
end makeButton

private command makeShape pName, pGroup, pMain
   local tShape
   put pName && "Shape" into tShape
   create graphic tShape in group pGroup
   set the style of graphic tShape to "roundrect"
   set the opaque of graphic tShape to true
   set the filled of graphic tShape to true
   set the antialiased of graphic tShape to true
   set the roundRadius of graphic tShape to 12
   if pMain then
      set the backgroundColor of graphic tShape to kAmber
      set the cUp of graphic tShape to kAmber
      set the cDown of graphic tShape to kAmberDown
      set the lineSize of graphic tShape to 0
   else
      set the backgroundColor of graphic tShape to kPanel
      set the cUp of graphic tShape to kPanel
      set the cDown of graphic tShape to kPanelDown
      set the lineSize of graphic tShape to 2
      set the foregroundColor of graphic tShape to kEdge
   end if
end makeShape

private command makeFace pName, pLabel, pGroup, pMain
   create button pName in group pGroup
   set the style of button pName to "transparent"
   set the showBorder of button pName to false
   set the threeD of button pName to false
   set the opaque of button pName to false
   set the autoHilite of button pName to false
   set the showFocusBorder of button pName to false
   set the traversalOn of button pName to false
   set the showName of button pName to true
   set the label of button pName to pLabel
   set the textFont of button pName to kFont
   set the textStyle of button pName to "bold"
   if pMain then
      set the textSize of button pName to 19
      set the cSize of button pName to 19
      set the textColor of button pName to kDark
   else
      set the textSize of button pName to 14
      set the cSize of button pName to 14
      set the textColor of button pName to kInk
   end if
   set the script of button pName to buttonScript()
end makeFace

-- Every button of the screens: pressed, it looks pressed; let go on it,
-- it does what it is for (ebPress, in the stack's script). A second tap
-- soon after the first comes as mouseDoubleDown and mouseDoubleUp.
private function buttonScript
   return "on mouseDown" & return & "   ebButtonLook the short name of me, true" & return & "end mouseDown" & return & \
         "on mouseDoubleDown" & return & "   ebButtonLook the short name of me, true" & return & "end mouseDoubleDown" & return & \
         "on mouseUp" & return & "   ebButtonLook the short name of me, false" & return & \
         "   ebPress the short name of me" & return & "end mouseUp" & return & \
         "on mouseDoubleUp" & return & "   ebButtonLook the short name of me, false" & return & \
         "   ebPress the short name of me" & return & "end mouseDoubleUp" & return & \
         "on mouseRelease" & return & "   ebButtonLook the short name of me, false" & return & "end mouseRelease"
end buttonScript

-- A filled rectangle with no border
private command setBox pObject, pColor
   set the style of pObject to "rectangle"
   set the opaque of pObject to true
   set the filled of pObject to true
   set the lineSize of pObject to 0
   set the showBorder of pObject to false
   set the backgroundColor of pObject to pColor
end setBox

-- A filled circle with no border
private command setOval pObject, pColor
   set the style of pObject to "oval"
   set the opaque of pObject to true
   set the filled of pObject to true
   set the lineSize of pObject to 0
   set the antialiased of pObject to true
   set the backgroundColor of pObject to pColor
end setOval

-- A field that is a label, in the game's font: locked, no frame, no
-- focus, and no margins but 4 points above its line, which is where a
-- field's first line begins: with none, the tops of small words (a
-- chip's, 10 points) were cut off. The game places it to the point
private command setLabel pField, pText, pSize, pColor, pStyle, pAlign
   set the lockText of pField to true
   set the traversalOn of pField to false
   set the opaque of pField to false
   set the showBorder of pField to false
   set the threeD of pField to false
   set the dontWrap of pField to true
   set the margins of pField to "0,4,0,0"
   set the textFont of pField to kFont
   set the textSize of pField to pSize
   set the cSize of pField to pSize
   set the textColor of pField to pColor
   set the textStyle of pField to pStyle
   set the textAlign of pField to pAlign
   set the text of pField to pText
end setLabel

-- A field of words, in the game's font, that wraps. It has 4 points
-- above and below its lines: with no margins, a field as tall as its
-- formattedHeight cut off the tops of its first line and the tails of
-- its last (y, g, p), on Windows and in a browser
private command setText pField, pText, pSize, pColor, pAlign
   set the lockText of pField to true
   set the traversalOn of pField to false
   set the opaque of pField to false
   set the showBorder of pField to false
   set the threeD of pField to false
   set the dontWrap of pField to false
   set the margins of pField to "0,4,0,4"
   set the textFont of pField to kFont
   set the textSize of pField to pSize
   set the cSize of pField to pSize
   set the textColor of pField to pColor
   set the textAlign of pField to pAlign
   set the text of pField to pText
end setText

-- The stack's script: ember-bricks-stack.livecodescript beside this file,
-- without its first line (a script-only stack's header, there so that
-- editors and checkers read it as xTalk)
private function stackScript
   local tFile, tScript
   put the effective filename of me into tFile
   set the itemDelimiter to slash
   put "ember-bricks-stack.livecodescript" into the last item of tFile
   set the itemDelimiter to comma
   put fileText(tFile) into tScript
   delete line 1 of tScript
   return tScript
end stackScript
