script "WobbleFortsBuilder"
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

-- Builds stacks/Wobble Forts.oxtstack, a physics game for a phone or a
-- window, played on Box2D through Box2Dxt (the xTalk Suite's) and the
-- Mobile Web library. The stack is never edited by hand: change this
-- script, the game's script (wobble-forts-stack.livecodescript) or its
-- levels (wobble-forts/levels.txt), and build it again, with any
-- OXT-Beyond engine (the IDE's, or the development engine of a build):
--
--    <engine> -ui tools/web-player/wobble-forts.livecodescript
--
-- OXT_WOBBLE_FORTS names another file to write. It prints "BUILT <file>"
-- or "FAILED <why>".
--
-- What goes in:
--   card "Art"    every picture of wobble-forts/art (art.txt). The game
--                 copies one into a sprite (an image of card "Fort") as it
--                 needs it, and draws it turned and at the size of the
--                 window: the files have two pixels to a unit of the
--                 world, so a phone's screen shows them sharp. The card is
--                 never shown.
--   card "Fort"   the game: the sky, the ground, the launcher, a fixed set
--                 of sprites for the blocks, aliens, dots and puffs (made
--                 once, shown and hidden, never created while it plays),
--                 the HUD, and the screens (Title, Map, Howto, Paused,
--                 Clear, Fail, Notice), each a group over the world
--   the levels    wobble-forts/levels.txt, as the custom property cLevels
--   the sounds    wobble-forts/sounds, as the custom property set cSounds
--   the font      Kenney Future Narrow, as the custom property cFont,
--                 which the game hands to "start using font file"
--
-- Every place and size of a control is set by the game's wfLayout as it
-- opens and whenever the window changes: here they are only made, with
-- their look. The stack's script is set last, so that nothing it does
-- runs while the stack is built.

constant kWidth = 960
constant kHeight = 540

-- The sprites: name of the pool and how many
constant kPieces = 72
constant kFx = 28
constant kPops = 6
constant kAimDots = 16
constant kTrail = 36
constant kGround = 44
constant kDeco = 10
constant kQueue = 6

-- The look (the game's script has the same colours)
constant kFont = "Kenney Future Narrow"
constant kInk = "#3B2410"
constant kCream = "#FFF4DC"
constant kEdge = "#6B4423"
constant kWhite = "#FFFFFF"

on startup
   local tFile, tError
   put $OXT_WOBBLE_FORTS into tFile
   if tFile is empty then
      put the effective filename of me into tFile
      set the itemDelimiter to slash
      put "stacks/Wobble Forts.oxtstack" into the last item of tFile
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
   local tName, tScript
   put "Wobble Forts" into tName
   if there is a stack tName then
      delete stack tName
   end if
   create invisible stack tName
   set the defaultStack to tName
   set the rect of stack tName to 100, 60, 100 + kWidth, 60 + kHeight
   set the minWidth of stack tName to 320
   set the minHeight of stack tName to 300
   set the resizable of stack tName to true
   set the backgroundColor of stack tName to "#D0F4F7"
   set the textFont of stack tName to empty
   set the textSize of stack tName to 14
   -- the page calls wfPageHidden when it is hidden (another app, a
   -- locked phone), so that a shot never plays on behind it; wfState says
   -- how the game is, for the checks that play it in a browser
   -- (tools/pages/check_wobble_forts_page.py)
   set the cJavascriptHandlers of stack tName to "wfPageHidden" & return & "wfState"

   set the name of card 1 of stack tName to "Fort"
   create card "Art"
   importArt
   importSounds tName
   importFont tName
   set the cLevels of stack tName to fileText(assetPath("levels.txt"))

   go card "Fort" of stack tName
   -- the sky's own colour above its hills (a colour, not a pattern: a
   -- card's pattern is drawn again with every pixel it draws)
   set the backgroundColor of card "Fort" to "#D0F4F7"
   buildWorld
   buildHud
   buildShade
   buildTitle
   buildMap
   buildHowto
   buildPaused
   buildClear
   buildFail
   buildNotice

   -- last: the script, which lays everything out as the stack opens
   put stackScript() into tScript
   set the script of stack tName to tScript
   if the result is not empty then
      throw "the stack's script does not compile:" && the result
   end if
   set the visible of stack tName to true
   save stack tName as pFile
   if the result is not empty then
      throw "cannot save" && pFile & ":" && the result
   end if
end buildStack

-- A file beside this script, in wobble-forts/
private function assetPath pName
   local tFile
   put the effective filename of me into tFile
   set the itemDelimiter to slash
   put "wobble-forts/" & pName into the last item of tFile
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

-- Every picture of art.txt. Its cSize is its size in the world (or, for
-- an icon or a logo, in points), from art.txt: the game draws it at that
-- size times the window's scale, whatever the number of its pixels
private command importArt
   local tLine, tName, tFile, tCount
   put 0 into tCount
   repeat for each line tLine in fileText(assetPath("art/art.txt"))
      if tLine is empty or char 1 of tLine is "#" then
         next repeat
      end if
      set the itemDelimiter to tab
      put item 1 of tLine into tName
      put item 2 of tLine into tFile
      import paint from file assetPath("art/" & tFile)
      if the result is not empty then
         throw "cannot import" && tFile & ":" && the result
      end if
      set the name of last image to tName
      set the cSize of image tName to item 3 of tLine & comma & item 4 of tLine
      set the itemDelimiter to comma
      set the lockLoc of image tName to true
      set the visible of image tName to false
      add 1 to tCount
   end repeat
   if tCount < 140 then
      throw "the pictures are not all there:" && tCount
   end if
end importArt

private command importSounds pStack
   local tFolder, tFile, tFiles
   put assetPath("sounds") into tFolder
   set the defaultFolder to tFolder
   put the files into tFiles
   repeat for each line tFile in tFiles
      if tFile ends with ".wav" then
         set the cSounds[char 1 to -5 of tFile] of stack pStack to fileData(tFolder & "/" & tFile)
      end if
   end repeat
   if the number of lines of the customKeys["cSounds"] of stack pStack < 24 then
      throw "the sounds are not all there:" && the customKeys["cSounds"] of stack pStack
   end if
end importSounds

private command importFont pStack
   set the cFont of stack pStack to fileData(assetPath("fonts/kenney_future_narrow.ttf"))
end importFont

-- The world, back to front: the sky, the hills' scenery, the launcher's
-- post and back band, the trail of the last shot and the aiming dots,
-- the Bloops waiting their turn, the pieces (blocks, aliens, the Bloop in
-- flight), the ground, the front band and the Bloop in the launcher,
-- then the puffs and the floating scores
private command buildWorld
   local i
   makeSprite "Sky", "sky-meadow"
   repeat with i = 1 to kDeco
      makeSprite "Deco" && i, "bush"
   end repeat
   makeSprite "Post", "wood-pillar-whole"
   makeSprite "Fork", "wood-cube-whole"
   makeBand "Band Back"
   repeat with i = 1 to kTrail
      makeDot "Trail" && i, "#FFFFFF", 25
   end repeat
   repeat with i = 1 to kAimDots
      makeDot "Aim" && i, "#FFFFFF", 10
   end repeat
   repeat with i = 1 to kQueue
      makeSprite "Queue" && i, "bloop-yellow"
   end repeat
   repeat with i = 1 to kPieces
      makeSprite "Piece" && i, "wood-cube-whole"
   end repeat
   create graphic "Dirt"
   setBox the long id of graphic "Dirt", "#8C5A2B"
   repeat with i = 1 to kGround
      makeSprite "Ground" && i, "ground-grass"
   end repeat
   makeSprite "Loaded", "bloop-yellow"
   makeBand "Band Front"
   repeat with i = 1 to kFx
      makeSprite "Fx" && i, "puff"
   end repeat
   repeat with i = 1 to kPops
      create field ("Pop" && i)
      setLabel the long id of field ("Pop" && i), empty, 18, kWhite, "bold", "center"
      set the visible of field ("Pop" && i) to false
   end repeat
   create graphic "Flash"
   setBox the long id of graphic "Flash", "#FFFFFF"
   set the blendLevel of graphic "Flash" to 40
   set the visible of graphic "Flash" to false
end buildWorld

-- A sprite: an image that the game gives a picture of card "Art" (its
-- text) and a rect; lockLoc, so that turning it keeps its rect
private command makeSprite pName, pPicture, pGroup
   if pGroup is empty then
      create image pName
   else
      create image pName in group pGroup
   end if
   -- a sprite of the world is given its picture as it is used (copied
   -- here, 150 sprites would carry their pictures in the stack again)
   if pGroup is not empty then
      set the text of image pName to the text of image pPicture of card "Art"
   end if
   set the lockLoc of image pName to true
   set the cPicture of image pName to pPicture
   -- a sprite of the world is shown when it is used; one of a screen
   -- shows with its group
   set the visible of image pName to (pGroup is not empty)
end makeSprite

-- A dot of the aim or the trail: a white circle, part see-through
private command makeDot pName, pColor, pBlend
   create graphic pName
   set the style of graphic pName to "oval"
   set the opaque of graphic pName to true
   set the filled of graphic pName to true
   -- a white dot with a brown rim, seen on the sky and on the grass
   set the lineSize of graphic pName to 1
   set the foregroundColor of graphic pName to "#6B4423"
   set the antialiased of graphic pName to true
   set the backgroundColor of graphic pName to pColor
   set the blendLevel of graphic pName to pBlend
   set the visible of graphic pName to false
end makeDot

-- A band of the launcher: a thick dark line
private command makeBand pName
   create graphic pName
   set the style of graphic pName to "line"
   set the lineSize of graphic pName to 6
   set the capStyle of graphic pName to "round"
   set the antialiased of graphic pName to true
   set the foregroundColor of graphic pName to "#4A2A12"
   set the visible of graphic pName to false
end makeBand

-- The level's name, the score, the Bloops' hint and the pause button
private command buildHud
   create group "HUD"
   makeButton "Pause", empty, "icon-pause", "blue", "HUD"
   create field "Level Name" in group "HUD"
   setLabel the long id of field "Level Name", "1-1", 18, kInk, "plain", "left"
   create field "Score" in group "HUD"
   setLabel the long id of field "Score", "0", 26, kInk, "plain", "right"
   create field "Score Label" in group "HUD"
   setLabel the long id of field "Score Label", "SCORE", 11, kEdge, "plain", "right"
   create field "Hint" in group "HUD"
   setText the long id of field "Hint", empty, 15, kInk, "center"
   set the textFont of field "Hint" to kFont
   set the visible of group "HUD" to false
end buildHud

-- The veil over the world, behind a panel
private command buildShade
   create graphic "Shade"
   setBox the long id of graphic "Shade", "#1B1430"
   set the blendLevel of graphic "Shade" to 45
   set the visible of graphic "Shade" to false
end buildShade

private command buildTitle
   create group "Title"
   makeSprite "Logo Wobble", "logo-wobble", "Title"
   makeSprite "Logo Forts", "logo-forts", "Title"
   create field "Tagline" in group "Title"
   setText the long id of field "Tagline", "Fling the Bloops. Topple the Grumps' wobbly forts.", 16, kInk, "center"
   set the textFont of field "Tagline" to kFont
   makeButton "Play", "PLAY", empty, "yellow", "Title"
   makeButton "Title Howto", empty, "icon-question", "blue", "Title"
   makeButton "Title Sound", empty, "icon-audio-on", "blue", "Title"
   makeButton "Title Full", empty, "icon-larger", "blue", "Title"
   create field "Records" in group "Title"
   setLabel the long id of field "Records", empty, 14, kInk, "plain", "center"
   create field "Turn Hint" in group "Title"
   setText the long id of field "Turn Hint", "Turn your phone on its side for a bigger fort.", 14, kEdge, "center"
   set the textFont of field "Turn Hint" to kFont
   set the visible of group "Title" to false
end buildTitle

-- The levels of one land at a time: five tiles, each its number, its
-- stars and its lock, with arrows to the other lands
private command buildMap
   local i, k
   create group "Map"
   makePanel "Map"
   create field "Map Title" in group "Map"
   setLabel the long id of field "Map Title", "MEADOW", 24, kInk, "plain", "center"
   create field "Map Sub" in group "Map"
   setLabel the long id of field "Map Sub", empty, 13, kEdge, "plain", "center"
   repeat with i = 1 to 5
      makeButton "Tile" && i, i, empty, "yellow", "Map"
      repeat with k = 1 to 3
         makeSprite "Tile" && i && "Star" && k, "star-gold", "Map"
      end repeat
      makeSprite "Tile" && i && "Lock", "icon-locked", "Map"
   end repeat
   makeButton "Map Prev", empty, "icon-left", "blue", "Map"
   makeButton "Map Next", empty, "icon-right", "blue", "Map"
   makeButton "Map Home", empty, "icon-home", "blue", "Map"
   create field "Map Stars" in group "Map"
   setLabel the long id of field "Map Stars", empty, 15, kInk, "plain", "right"
   makeSprite "Map Star", "star-gold", "Map"
   set the visible of group "Map" to false
end buildMap

private command buildHowto
   local i, tTexts, tIcons
   create group "Howto"
   makePanel "Howto"
   create field "Howto Title" in group "Howto"
   setLabel the long id of field "Howto Title", "HOW TO PLAY", 24, kInk, "plain", "center"
   put "Pull the Bloop back from anywhere on the screen, aim along the dots and let go." & return & \
         "Tap while a Bloop flies: Zip dashes, Trio splits in three, Thud drops like a stone, Boom goes bang." & return & \
         "Pop every Grump to clear the fort. Bloops to spare earn more stars." into tTexts
   put "bloop-yellow,bloop-blue,grump-green" into tIcons
   repeat with i = 1 to 3
      makeSprite "Howto Icon" && i, item i of tIcons, "Howto"
      create field ("Howto Text" && i) in group "Howto"
      setText the long id of field ("Howto Text" && i), line i of tTexts, 15, kInk, "left"
   end repeat
   makeButton "Howto Go", "GOT IT", empty, "yellow", "Howto"
   set the visible of group "Howto" to false
end buildHowto

private command buildPaused
   create group "Paused"
   makePanel "Paused"
   create field "Paused Title" in group "Paused"
   setLabel the long id of field "Paused Title", "PAUSED", 26, kInk, "plain", "center"
   makeButton "Resume", "RESUME", empty, "yellow", "Paused"
   makeButton "Pause Restart", empty, "icon-return", "blue", "Paused"
   makeButton "Pause Levels", empty, "icon-menu-grid", "blue", "Paused"
   makeButton "Pause Sound", empty, "icon-audio-on", "blue", "Paused"
   set the visible of group "Paused" to false
end buildPaused

private command buildClear
   local k
   create group "Clear"
   makePanel "Clear"
   create field "Clear Title" in group "Clear"
   setLabel the long id of field "Clear Title", "FORT DOWN!", 28, kInk, "plain", "center"
   repeat with k = 1 to 3
      makeSprite "Clear Star" && k, "star-gold", "Clear"
   end repeat
   create field "Clear Score" in group "Clear"
   setLabel the long id of field "Clear Score", "0", 30, kInk, "plain", "center"
   create field "Clear Best" in group "Clear"
   setLabel the long id of field "Clear Best", empty, 13, kEdge, "plain", "center"
   makeButton "Clear Levels", empty, "icon-menu-grid", "blue", "Clear"
   makeButton "Clear Replay", empty, "icon-return", "blue", "Clear"
   makeButton "Clear Next", "ONWARD", empty, "green", "Clear"
   set the visible of group "Clear" to false
end buildClear

private command buildFail
   create group "Fail"
   makePanel "Fail"
   create field "Fail Title" in group "Fail"
   setLabel the long id of field "Fail Title", "OUT OF BLOOPS", 26, kInk, "plain", "center"
   create field "Fail Text" in group "Fail"
   setText the long id of field "Fail Text", empty, 15, kEdge, "center"
   set the textFont of field "Fail Text" to kFont
   makeSprite "Fail Grump", "grump-green", "Fail"
   makeButton "Fail Levels", empty, "icon-menu-grid", "blue", "Fail"
   makeButton "Fail Retry", "TRY AGAIN", empty, "yellow", "Fail"
   set the visible of group "Fail" to false
end buildFail

-- Shown instead of the title when Box2D cannot be had (a desktop engine
-- without the Box2Dxt extension)
private command buildNotice
   create group "Notice"
   makePanel "Notice"
   create field "Notice Title" in group "Notice"
   setLabel the long id of field "Notice Title", "NO PHYSICS HERE", 22, kInk, "plain", "center"
   create field "Notice Text" in group "Notice"
   setText the long id of field "Notice Text", "Wobble Forts plays on Box2D, through the Box2Dxt extension. " & \
         "Turn on Box2Dxt in Tools > Extension Manager and open the stack again, or play it in the Stack Player in a browser.", 15, kInk, "center"
   set the visible of group "Notice" to false
end buildNotice

-- A panel: a cream card with a brown rim and a shadow under it
private command makePanel pGroup
   create graphic (pGroup && "Shadow") in group pGroup
   setRound the long id of graphic (pGroup && "Shadow"), "#000000", empty
   set the blendLevel of graphic (pGroup && "Shadow") to 70
   create graphic (pGroup && "Card") in group pGroup
   setRound the long id of graphic (pGroup && "Card"), kCream, kEdge
   set the lineSize of graphic (pGroup && "Card") to 4
end makePanel

-- A button: its lip (a darker rounded box under it), its face, an icon
-- or a label on it, and over them a button with no look of its own,
-- which takes the taps. The game sets their rects; the face's cUp and
-- cDown are its colours, up and pressed.
private command makeButton pName, pLabel, pIcon, pColor, pGroup
   local tFace, tLip
   switch pColor
      case "yellow"
         put "#FFCC33" into tFace
         put "#C98F12" into tLip
         break
      case "green"
         put "#7AC943" into tFace
         put "#4A8F22" into tLip
         break
      case "blue"
         put "#5AB0F0" into tFace
         put "#2F78B8" into tLip
         break
      default
         put kCream into tFace
         put "#B58B5A" into tLip
   end switch
   create graphic (pName && "Lip") in group pGroup
   setRound the long id of graphic (pName && "Lip"), tLip, empty
   create graphic (pName && "Face") in group pGroup
   setRound the long id of graphic (pName && "Face"), tFace, empty
   set the cUp of graphic (pName && "Face") to tFace
   set the cDown of graphic (pName && "Face") to tLip
   if pIcon is not empty then
      makeSprite pName && "Icon", pIcon, pGroup
      set the visible of image (pName && "Icon") to true
   end if
   if pLabel is not empty then
      create field (pName && "Label") in group pGroup
      if pColor is "yellow" or pColor is "cream" then
         setLabel the long id of field (pName && "Label"), pLabel, 22, kInk, "plain", "center"
      else
         setLabel the long id of field (pName && "Label"), pLabel, 22, kWhite, "plain", "center"
      end if
   end if
   create button pName in group pGroup
   set the style of button pName to "transparent"
   set the showBorder of button pName to false
   set the threeD of button pName to false
   set the opaque of button pName to false
   set the autoHilite of button pName to false
   set the showFocusBorder of button pName to false
   set the traversalOn of button pName to false
   set the showName of button pName to false
   set the script of button pName to buttonScript()
end makeButton

-- Every button of the screens: pressed, it looks pressed; let go on it,
-- it does what it is for (wfPress, in the stack's script). A second tap
-- soon after the first comes as mouseDoubleDown and mouseDoubleUp.
private function buttonScript
   return "on mouseDown" & return & "   wfButtonLook the short name of me, true" & return & "end mouseDown" & return & \
         "on mouseDoubleDown" & return & "   wfButtonLook the short name of me, true" & return & "end mouseDoubleDown" & return & \
         "on mouseUp" & return & "   wfButtonLook the short name of me, false" & return & \
         "   wfPress the short name of me" & return & "end mouseUp" & return & \
         "on mouseDoubleUp" & return & "   wfButtonLook the short name of me, false" & return & \
         "   wfPress the short name of me" & return & "end mouseDoubleUp" & return & \
         "on mouseRelease" & return & "   wfButtonLook the short name of me, false" & return & "end mouseRelease"
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

-- A filled rounded rectangle, with a rim of pEdge (none when empty)
private command setRound pObject, pColor, pEdge
   set the style of pObject to "roundrect"
   set the roundRadius of pObject to 14
   set the opaque of pObject to true
   set the filled of pObject to true
   set the antialiased of pObject to true
   set the backgroundColor of pObject to pColor
   if pEdge is empty then
      set the lineSize of pObject to 0
   else
      set the lineSize of pObject to 3
      set the foregroundColor of pObject to pEdge
   end if
end setRound

-- A field that is a label, in the game's font: locked, no frame, no
-- focus, no margins (the game places it to the point)
private command setLabel pField, pText, pSize, pColor, pStyle, pAlign
   set the lockText of pField to true
   set the traversalOn of pField to false
   set the opaque of pField to false
   set the showBorder of pField to false
   set the threeD of pField to false
   set the dontWrap of pField to true
   set the margins of pField to 0
   set the textFont of pField to kFont
   set the textSize of pField to pSize
   set the textColor of pField to pColor
   set the textStyle of pField to pStyle
   set the textAlign of pField to pAlign
   set the text of pField to pText
end setLabel

-- A field of words that wraps. It is 4 points deeper above and below its
-- lines: with no margins, a field as tall as its formattedHeight cut off
-- the tops of its first line and the tails of its last, on Windows and in
-- a browser
private command setText pField, pText, pSize, pColor, pAlign
   set the lockText of pField to true
   set the traversalOn of pField to false
   set the opaque of pField to false
   set the showBorder of pField to false
   set the threeD of pField to false
   set the dontWrap of pField to false
   set the margins of pField to "0,4,0,4"
   set the textSize of pField to pSize
   set the textColor of pField to pColor
   set the textAlign of pField to pAlign
   set the text of pField to pText
end setText

-- The stack's script: wobble-forts-stack.livecodescript beside this
-- file, without its first line (a script-only stack's header, there so
-- that editors and checkers read it as xTalk)
private function stackScript
   local tFile, tScript
   put the effective filename of me into tFile
   set the itemDelimiter to slash
   put "wobble-forts-stack.livecodescript" into the last item of tFile
   set the itemDelimiter to comma
   put fileText(tFile) into tScript
   delete line 1 of tScript
   return tScript
end stackScript
